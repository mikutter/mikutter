# -*- coding: utf-8 -*-

module Plugin::Mastodon
  CLIENT_NAME = Environment::NAME
  WEB_SITE = 'https://mikutter.hachune.net/'
end

require_relative 'util'
require_relative 'api'
require_relative 'parser'
require_relative 'model/model'
require_relative 'patch'
require_relative 'spell'
require_relative 'setting'
require_relative 'subparts_status_info'
require_relative 'extractcondition'
require_relative 'score'

Plugin.create(:mastodon) do
  defimageopener(_('Mastodon添付画像'), %r<\Ahttps?://[^/]+/system/media_attachments/files/[0-9]{3}/[0-9]{3}/[0-9]{3}/\w+/\w+\.\w+(?:\?\d+)?\Z>) do |url|
    URI.open(url)
  end

  defimageopener(_('Mastodon添付画像（短縮）'), %r<\Ahttps?://[^/]+/media/[0-9A-Za-z_-]+(?:\?\d+)?\Z>) do |url|
    URI.open(url)
  end

  defimageopener(_('Mastodon添付画像(proxy)'), %r<\Ahttps?://[^/]+/media_proxy/[0-9]+/(?:original|small)\z>) do |url|
    URI.open(url)
  end

  # すべてのmastodon worldを返す
  defevent :mastodon_worlds, prototype: [Pluggaloid::COLLECT]

  # Mastodonサーバの集合。
  defevent :mastodon_servers, prototype: [Pluggaloid::COLLECT]

  defevent :mastodon_appear_toots, prototype: [Pluggaloid::STREAM]

  # ユーザの直接の操作によってバックグラウンド通信を行った結果、成功した時の通知
  # （例: トゥートを投稿した、ふぁぼった等）
  defactivity :mastodon_background_succeeded, _('Mastodonのバックグラウンド通信の成功')

  # ユーザの直接の操作によってバックグラウンド通信を行った結果、失敗した時の通知
  # （例: トゥートを投稿するために通信したら、サーバエラーが返ってきた等）
  defactivity :mastodon_background_failed, _('Mastodonのバックグラウンド通信の失敗')

  defactivity :mastodon_followings_update, _('プロフィール・フォロー関係の取得通知(Mastodon)')

  filter_extract_datasources do |dss|
    datasources = { mastodon_appear_toots: _('受信したすべてのトゥート(Mastodon)') }
    [datasources.merge(dss)]
  end

  # データソース「mastodon_appear_toots」の定義
  generate(:extract_receive_message, :mastodon_appear_toots) do |appear|
    subscribe(:mastodon_appear_toots, &appear.method(:bulk_add))
  end

  # shareされたトゥートに関してイベントを発生させる
  subscribe(:mastodon_appear_toots).each do |message|
    if message.reblog?
      Plugin.call(:share, message.user, message.reblog)
      message.to_me_world&.yield_self do |world|
        Plugin.call(:mention, world, [message])
      end
    end
  end

  followings_updater = -> do
    activity(:mastodon_followings_update, _('自分のプロフィールやフォロー関係を取得しています...'))
    Plugin.collect(:mastodon_worlds).each do |world|
      Delayer::Deferred.when(
        world.update_account,
        world.blocks,
        world.followings(cache: false)
      ).next{
        activity(:mastodon_followings_update, _('自分のプロフィールやフォロー関係の取得が完了しました(%{acct})') % {acct: world.account.acct})
        Plugin.call(:world_modify, world)
      }.terminate(_('自分のプロフィールやフォロー関係が取得できませんでした(%{acct})') % {acct: world.account.acct})
    end

    Delayer.new(delay: 10 * HYDE, &followings_updater) # 26分ごとにプロフィールとフォロー一覧を更新する
  end

  # 起動時
  Delayer.new {
    followings_updater.call
  }

  # Mastodonサーバが初期化されたら、サーバの集合に加える
  collection(:mastodon_servers) do |servers|
    on_mastodon_server_created do |server|
      servers.rewind do |stored|
        stored << server unless stored.include?(server)
        stored
      end
    end
  end

  # 存在するサーバやWorldに応じて、選択できる全ての抽出タブデータソースを提示する
  collection(:message_stream) do |message_stream|
    subscribe(:mastodon_worlds__add) do |worlds|
      message_stream.rewind do |a|
        a | worlds.flat_map{|world| [world.sse.user, world.sse.direct] }
      end
      worlds.each do |world|
        world.get_lists.next do |lists|
          message_stream.rewind do |a|
            a | lists.map do |list|
              world.sse.list(list_id: list[:id], title: list[:title])
            end
          end
        end
      end
    end

    subscribe(:mastodon_servers__add).each do |server|
      message_stream.rewind do |a|
        a | [
          server.sse.public,
          server.sse.public(only_media: true),
          server.sse.public_local,
          server.sse.public_local(only_media: true)
        ]
      end
    end
  end

  # world系

  collection(:mastodon_worlds) do |mutation|
    subscribe(:worlds__add).select { |world|
      world.class.slug == :mastodon
    }.each(&mutation.method(:add))

    subscribe(:worlds__delete).each(&mutation.method(:delete))
  end

  defevent :mastodon_current, prototype: [NilClass]

  # world_currentがmastodonならそれを、そうでなければ適当に探す。
  filter_mastodon_current do
    world, = Plugin.filtering(:world_current, nil)
    unless mastodon?(world)
      world = Plugin.collect(:mastodon_worlds).first
    end
    [world]
  end

  # サーバー編集
  on_mastodon_update_instance do |domain|
    Thread.new {
      instance = Plugin::Mastodon::Instance.load(domain)
      next unless instance
    }
  end

  # サーバー削除
  on_mastodon_delete_instance do |domain|
    if UserConfig[:mastodon_instances].has_key?(domain)
      config = UserConfig[:mastodon_instances].dup
      config.delete(domain)
      UserConfig[:mastodon_instances] = config
    end
  end

  # world追加時用
  on_mastodon_create_or_update_instance do |domain|
    Plugin::Mastodon::Instance.add_ifn(domain)
  end

  on_world_create do |world|
    next unless world.class.slug == :mastodon

    slug_param = {id: Digest::SHA1.hexdigest(world.uri.to_s), domain: world.domain}
    name_param = {name: world.user_obj.acct, domain: world.domain}
    htl_slug = ('mastodon_htl_%{id}' % slug_param).to_sym
    mention_slug = ('mastodon_mentions_%{id}' % slug_param).to_sym
    ltl_slug = ('mastodon_ltl_%{domain}' % slug_param).to_sym
    exists_slugs = Set.new(Plugin.filtering(:extract_tabs_get, []).first.map(&:slug))
    unless exists_slugs.include? htl_slug
      Plugin.call(:extract_tab_create, {
                    name: _('ホームタイムライン (%{name})') % name_param,
                    slug: htl_slug,
                    sources: [world.sse.user.datasource_slug],
                    icon: Skin[:timeline].uri,
                  })
    end
    unless exists_slugs.include? mention_slug
      Plugin.call(:extract_tab_create, {
                    name: _('メンション (%{name})') % name_param,
                    slug: mention_slug,
                    sources: [:mastodon_appear_toots],
                    sexp: [:or, [:include?, :receiver_idnames, world.user_obj.idname]],
                    icon: Skin[:reply].uri,
                  })
    end
    unless exists_slugs.include? ltl_slug
      Plugin.call(:extract_tab_create, {
                    name: _('ローカルタイムライン (%{domain})') % name_param,
                    slug: ltl_slug,
                    sources: [world.sse.public_local.datasource_slug],
                    icon: 'https://%{domain}/apple-touch-icon.png' % slug_param,
                  })
    end
  end

  # world追加
  on_world_create do |world|
    if world.class.slug == :mastodon
      Plugin.call(:mastodon_create_or_update_instance, world.domain, true)
    end
  end

  # world作成
  world_setting(:mastodon, _('Mastodon')) do
    set_value domain_selection: 'social.mikutter.hachune.net'
    error_msg = nil
    while true
      if error_msg.is_a? String
        label error_msg
      end
      select(_('サーバー'), :domain_selection,
             'social.mikutter.hachune.net' => _('mikutter'),
             'mstdn.maud.io' => _('末代'),
             'mstdn.nere9.help' => _('nere9'),
             'mstdn.y-zu.org' => _('Yづドン'),
            ) do
        option(:other, _('その他')) do
          input _('ドメイン'), :domain
        end
      end

      result = await_input
      domain = result[:domain_selection] == :other ? result[:domain] : result[:domain_selection]

      instance = await Plugin::Mastodon::Instance.add_ifn(domain).trap{ nil }
      unless instance
        error_msg = _("%{domain} サーバーへの接続に失敗しました。やり直してください。") % {domain: domain}
        next
      end

      break
    end

    error_msg = nil
    while true
      if error_msg.is_a? String
        label error_msg
      end
      label _('Webページにアクセスして表示された認証コードを入力して、次へボタンを押してください。')
      link instance.authorize_url
      input _('認証コード'), :authorization_code
      if error_msg.is_a? String
        input _('アクセストークンがあれば入力してください'), :access_token
      end
      result = await_input
      if result[:authorization_code]
        result[:authorization_code].strip!
      end
      if result[:access_token]
        result[:access_token].strip!
      end

      if ((!result[:authorization_code] || result[:authorization_code].empty?) && (!result[:access_token] || result[:access_token].empty?))
        error_msg = _('認証コードを入力してください')
        next
      end

      break
    end

    if result[:authorization_code]
      resp = Plugin::Mastodon::API.call!(:post, domain, '/oauth/token',
                                         client_id: instance.client_key,
                                         client_secret: instance.client_secret,
                                         grant_type: 'authorization_code',
                                         redirect_uri: 'urn:ietf:wg:oauth:2.0:oob',
                                         code: result[:authorization_code]
                                        )
      if !resp || resp.value.has_key?(:error)
        label _('認証に失敗しました。') + (resp && resp[:error] ? "：#{resp[:error]}" : '')
        await_input
        raise (resp ? resp[:error] : 'error has occurred at /oauth/token')
      end
      token = resp[:access_token]
    else
      token = result[:access_token]
    end

    resp = Plugin::Mastodon::API.call!(:get, domain, '/api/v1/accounts/verify_credentials', token)
    if resp.nil? || resp.value.has_key?(:error)
      label _('アカウント情報の取得に失敗しました') + (resp && resp[:error] ? "：#{resp[:error]}" : '')
      raise (resp ? resp[:error] : 'error has occurred at verify_credentials')
    end

    screen_name = resp[:acct] + '@' + domain
    resp[:acct] = screen_name
    account = Plugin::Mastodon::Account.new(resp.value)
    world = Plugin::Mastodon::World.new(
      id: screen_name,
      slug: :"mastodon:#{screen_name}",
      domain: domain,
      access_token: token,
      account: account
    )
    world.update_mutes!

    label _('認証に成功しました。このアカウントを追加しますか？')
    label(_('アカウント名：%{screen_name}') % {screen_name: screen_name})
    label(_('ユーザー名：%{display_name}') % {display_name: resp[:display_name]})
    world
  end
end
