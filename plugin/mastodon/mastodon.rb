# -*- coding: utf-8 -*-

module Plugin::Mastodon
  PM = Plugin::Mastodon
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
require_relative 'rest'
require_relative 'score'

Plugin.create(:mastodon) do
  pm = Plugin::Mastodon

  defimageopener(_('Mastodon添付画像'), %r<\Ahttps?://[^/]+/system/media_attachments/files/[0-9]{3}/[0-9]{3}/[0-9]{3}/\w+/\w+\.\w+(?:\?\d+)?\Z>) do |url|
    open(url)
  end

  defimageopener(_('Mastodon添付画像（短縮）'), %r<\Ahttps?://[^/]+/media/[0-9A-Za-z_-]+(?:\?\d+)?\Z>) do |url|
    open(url)
  end

  defimageopener(_('Mastodon添付画像(proxy)'), %r<\Ahttps?://[^/]+/media_proxy/[0-9]+/(?:original|small)\z>) do |url|
    open(url)
  end

  defevent :mastodon_appear_toots, prototype: [[pm::Status]]

  defactivity :mastodon_followings_update, _('プロフィール・フォロー関係の取得通知(Mastodon)')

  filter_extract_datasources do |dss|
    datasources = { mastodon_appear_toots: _('受信したすべてのトゥート(Mastodon)') }
    [datasources.merge(dss)]
  end

  on_mastodon_appear_toots do |statuses|
    Plugin.call(:extract_receive_message, :mastodon_appear_toots, statuses)
  end

  followings_updater = -> do
    activity(:mastodon_followings_update, _('自分のプロフィールやフォロー関係を取得しています...'))
    Plugin.filtering(:mastodon_worlds, nil).first.to_a.each do |world|
      Delayer::Deferred.when(
        world.update_account,
        world.blocks,
        world.followings(cache: false)
      ).next{
        activity(:mastodon_followings_update, _('自分のプロフィールやフォロー関係の取得が完了しました(%{acct})') % {acct: world.account.acct})
        Plugin.call(:world_modify, world)
      }.terminate(_('自分のプロフィールやフォロー関係が取得できませんでした(%{acct})') % {acct: world.account.acct})
    end

    Reserver.new(10 * HYDE, &followings_updater) # 26分ごとにプロフィールとフォロー一覧を更新する
  end

  # 起動時
  Delayer.new {
    followings_updater.call
  }


  # world系

  defevent :mastodon_worlds, prototype: [NilClass]

  # すべてのmastodon worldを返す
  filter_mastodon_worlds do
    [Enumerator.new{|y|
      Plugin.filtering(:worlds, y)
    }.select{|world|
      world.class.slug == :mastodon
    }.to_a]
  end

  defevent :mastodon_current, prototype: [NilClass]

  # world_currentがmastodonならそれを、そうでなければ適当に探す。
  filter_mastodon_current do
    world, = Plugin.filtering(:world_current, nil)
    unless mastodon?(world)
      worlds, = Plugin.filtering(:mastodon_worlds, nil)
      world = worlds.first
    end
    [world]
  end

  on_userconfig_modify do |key, value|
    if [:mastodon_enable_streaming, :extract_tabs].include?(key)
      Plugin.call(:mastodon_restart_all_streams)
    end
  end

  # サーバー編集
  on_mastodon_update_instance do |domain|
    Thread.new {
      instance = pm::Instance.load(domain)
      next if instance.nil? # 既存にない

      Plugin.call(:mastodon_restart_instance_stream, domain)
    }
  end

  # サーバー削除
  on_mastodon_delete_instance do |domain|
    Plugin.call(:mastodon_remove_instance_stream, domain)
    if UserConfig[:mastodon_instances].has_key?(domain)
      config = UserConfig[:mastodon_instances].dup
      config.delete(domain)
      UserConfig[:mastodon_instances] = config
    end
  end

  # world追加時用
  on_mastodon_create_or_update_instance do |domain|
    pm::Instance.add_ifn(domain).next do
      Plugin.call(:mastodon_restart_instance_stream, domain)
    end
  end

  on_world_create do |world|
    if world.class.slug == :mastodon
      slug_param = {id: Digest::SHA1.hexdigest(world.uri.to_s), domain: world.domain}
      name_param = {name: world.user_obj.acct, domain: world.domain}
      htl_slug = ('mastodon_htl_%{id}' % slug_param).to_sym
      mention_slug = ('mastodon_mentions_%{id}' % slug_param).to_sym
      ltl_slug = ('mastodon_ltl_%{domain}' % slug_param).to_sym
      exists_slugs = Set.new(Plugin.filtering(:extract_tabs_get, []).first.map(&:slug))
      if !exists_slugs.include?(htl_slug)
        Plugin.call(:extract_tab_create, {
                      name: _('ホームタイムライン (%{name})') % name_param,
                      slug: htl_slug,
                      sources: [world.datasource_slug(:home)],
                      icon: Skin[:timeline].uri,
                    })
      end
      if !exists_slugs.include?(mention_slug)
        Plugin.call(:extract_tab_create, {
                      name: _('メンション (%{name})') % name_param,
                      slug: mention_slug,
                      sources: [:mastodon_appear_toots],
                      sexp: [:or, [:include?, :receiver_idnames, world.user_obj.idname]],
                      icon: Skin[:reply].uri,
                    })
      end
      if !exists_slugs.include?(ltl_slug)
        Plugin.call(:extract_tab_create, {
                      name: _('ローカルタイムライン (%{domain})') % name_param,
                      slug: ltl_slug,
                      sources: [Plugin::Mastodon::Instance.datasource_slug(world.domain, :local)],
                      icon: 'https://%{domain}/apple-touch-icon.png' % slug_param,
                    })
      end
    end
  end

  # world追加
  on_world_create do |world|
    if world.class.slug == :mastodon
      Plugin.call(:mastodon_create_or_update_instance, world.domain, true)
    end
  end

  # world削除
  on_world_destroy do |world|
    if world.class.slug == :mastodon
      Delayer.new {
        worlds = Plugin.filtering(:mastodon_worlds, nil).first
        # 他のworldで使わなくなったものは削除してしまう。
        # filter_worldsから削除されるのはココと同様にon_world_destroyのタイミングらしいので、
        # この時点では削除済みである保証はなく、そのためworld.slugで判定する必要がある（はず）。
        unless worlds.any?{|w| w.slug != world.slug && w.domain != world.domain }
          Plugin.call(:mastodon_delete_instance, world.domain)
        end
        Plugin.call(:mastodon_remove_auth_stream, world)
      }
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

      instance = await pm::Instance.add_ifn(domain).trap{ nil }
      if instance.nil?
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

      if ((result[:authorization_code].nil? || result[:authorization_code].empty?) && (result[:access_token].nil? || result[:access_token].empty?))
        error_msg = _('認証コードを入力してください')
        next
      end

      break
    end

    if result[:authorization_code]
      resp = pm::API.call!(:post, domain, '/oauth/token',
                           client_id: instance.client_key,
                           client_secret: instance.client_secret,
                           grant_type: 'authorization_code',
                           redirect_uri: 'urn:ietf:wg:oauth:2.0:oob',
                           code: result[:authorization_code]
                          )
      if resp.nil? || resp.value.has_key?(:error)
        label _('認証に失敗しました。') + (resp && resp[:error] ? "：#{resp[:error]}" : '')
        await_input
        raise (resp.nil? ? 'error has occurred at /oauth/token' : resp[:error])
      end
      token = resp[:access_token]
    else
      token = result[:access_token]
    end

    resp = pm::API.call!(:get, domain, '/api/v1/accounts/verify_credentials', token)
    if resp.nil? || resp.value.has_key?(:error)
      label _('アカウント情報の取得に失敗しました') + (resp && resp[:error] ? "：#{resp[:error]}" : '')
      raise (resp.nil? ? 'error has occurred at verify_credentials' : resp[:error])
    end

    screen_name = resp[:acct] + '@' + domain
    resp[:acct] = screen_name
    account = pm::Account.new(resp.value)
    world = pm::World.new(
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
