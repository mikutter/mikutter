# -*- coding: utf-8 -*-

require_relative 'model'
require_relative 'world'
require_relative 'api'
require_relative 'instance'
require_relative 'stream'

module Plugin::Worldon
  CLIENT_NAME = 'mikutter Worldon'
  WEB_SITE = 'https://github.com/cobodo/mikutter-worldon'
end

Plugin.create(:worldon) do
  PM = Plugin::Worldon

  # 各インスタンス向けアプリケーションキー用のストレージを確保しておく
  keys = at(:instances)
  if keys.nil?
    keys = Hash.new
    store(:instances, keys)
  end

  # ストリーム開始＆直近取得イベント
  defevent :worldon_start_stream, prototype: [String, String, String, String, Integer]

  defimageopener('Mastodon添付画像', %r<https?://[^/]+/media/\w+>) do |url|
    open(url)
  end

  defevent :worldon_worlds, prototype: [NilClass]

  # すべてのworldon worldを返す
  filter_worldon_worlds do
    [Enumerator.new{|y|
      Plugin.filtering(:worlds, y)
    }.select{|world|
      world.class.slug == :worldon_for_mastodon
    }.to_a]
  end

  defevent :current_worldon, prototype: [NilClass]

  # world_currentがworldonならそれを、そうでなければ適当に探す。
  filter_current_worldon do
    world, = Plugin.filtering(:world_current, nil)
    if world.class.slug != :worldon_for_mastodon
      worlds, = Plugin.filter(:worldon_worlds, nil)
      world = worlds.first
    end
    [world]
  end

  # ストリーム開始＆直近取得
  on_worldon_start_stream do |domain, type, slug, token, list_id|
    # ストリーム開始
    PM::Stream.start(domain, type, slug, token, list_id)

    # 直近の分を取得
    opts = { limit: 40 }
    path_base = '/api/v1/timelines/'
    case type
    when 'user'
      path = path_base + 'home'
    when 'public'
      path = path_base + 'public'
    when 'public:local'
      path = path_base + 'public'
      opts[:local] = 1
    when 'list'
      path = path_base + 'list/' + list_id.to_s
    end
    hashes = PM::API.call(:get, domain, path, token, opts)
    next if hashes.nil?
    arr = hashes
    if (hashes.is_a?(Hash) && hashes[:array].is_a?(Array))
      arr = hashes[:array]
    end
    tl = PM::Status.build(domain, arr)
    if domain.nil?
      puts "on_worldon_start_stream domain is null #{type} #{slug} #{token.to_s} #{list_id.to_s}"
      pp tl.select{|status| status.domain.nil? }
    end
    Plugin.call :extract_receive_message, slug, tl

    reblogs = tl.select{|status| status.reblog? }
    if !reblogs.empty?
      Plugin.call(:retweet, reblogs)
    end
  end

  defevent :worldon_appear_toots, prototype: [[PM::Status]]

  # 終了時
  onunload do
    PM::Stream.killall
  end

  # 起動時
  Thread.new {
    worlds, = Plugin.filtering(:worldon_worlds, nil)

    worlds.each do |world|
      world.update_mutes!
      PM::Stream.init_auth_stream(world)
    end

    worlds.map{|world|
      world.domain
    }.to_a.uniq.each{|domain|
      PM::Stream.init_instance_stream(domain)
    }
  }


  # spell系

  # 投稿
  defspell(:compose, :worldon_for_mastodon, condition: -> (world) { true }) do |world, body:, **opts|
    # TODO: PostBoxから渡ってくるoptsを適当に変換する
    if opts[:visibility].nil?
      opts.delete :visibility
    end
    world.post(body, opts)
  end

  defspell(:compose, :worldon_for_mastodon, :worldon_status,
           condition: -> (world, status) { true }
          ) do |world, status, body:, **opts|
    # TODO: PostBoxから渡ってくるoptsを適当に変換する
    if opts[:visibility].nil?
      opts.delete :visibility
    end
    status_id = status.id
    _status_id = PM::API.get_local_status_id(world, status)
    if !_status_id.nil?
      status_id = _status_id
      opts[:in_reply_to_id] = status_id
      hash = world.post(body, opts)
      if hash.nil?
        warn "投稿に失敗したかもしれません"
        pp hash
        nil
      else
        new_status = PM::Status.build(world.domain, [hash]).first
        Plugin.call(:posted, world, [new_status])
        Plugin.call(:update, world, [new_status])
        new_status
      end
    else
      warn "返信先Statusが#{world.domain}内に見つかりませんでした：#{status.url}"
      nil
    end
  end

  # ふぁぼ
  defevent :worldon_favorite, prototype: [PM::World, PM::Status]

  # ふぁぼる
  on_worldon_favorite do |world, status|
    # TODO: guiなどの他plugin向け通知イベントの調査
    status_id = PM::API.get_local_status_id(world, status.actual_status)
    if !status_id.nil?
      Plugin.call(:before_favorite, world, world.account, status)
      ret = PM::API.call(:post, world.domain, '/api/v1/statuses/' + status_id.to_s + '/favourite', world.access_token)
      if ret.nil? || ret[:error]
        Plugin.call(:fail_favorite, world, world.account, status)
      else
        status.actual_status.favourited = true
        Plugin.call(:favorite, world, world.account, status)
      end
    end
  end

  defspell(:favorite, :worldon_for_mastodon, :worldon_status,
           condition: -> (world, status) { !status.actual_status.favorite? } # TODO: favorite?の引数にworldを取って正しく判定できるようにする
          ) do |world, status|
    Plugin.call(:worldon_favorite, world, status.actual_status)
  end

  defspell(:favorited, :worldon_for_mastodon, :worldon_status,
           condition: -> (world, status) { status.actual_status.favorite? } # TODO: worldを使って正しく判定する
          ) do |world, status|
    Delayer::Deferred.new.next {
      status.actual_status.favorite? # TODO: 何を返せばいい？
    }
  end

  # ブーストイベント
  defevent :worldon_share, prototype: [PM::World, PM::Status]

  # ブースト
  on_worldon_share do |world, status|
    world.reblog(status).next{|shared|
      Plugin.call(:posted, world, [shared])
      Plugin.call(:update, world, [shared])
    }
  end

  defspell(:share, :worldon_for_mastodon, :worldon_status,
           condition: -> (world, status) { !status.actual_status.shared? } # TODO: shared?の引数にworldを取って正しく判定できるようにする
          ) do |world, status|
    world.reblog status
  end

  defspell(:shared, :worldon_for_mastodon, :worldon_status,
           condition: -> (world, status) { status.actual_status.shared? } # TODO: worldを使って正しく判定する
          ) do |world, status|
    Delayer::Deferred.new.next {
      status.actual_status.shared? # TODO: 何を返せばいい？
    }
  end


  # world系

  # world追加
  on_world_create do |world|
    if world.class.slug == :worldon_for_mastodon
      Delayer.new {
        PM::Stream.init_instance_stream(world.domain)
        PM::Stream.init_auth_stream(world)
      }
    end
  end

  # world削除
  on_world_destroy do |world|
    if world.class.slug == :worldon_for_mastodon
      Delayer.new {
        PM::Stream.remove_instance_stream(world.domain)
        PM::Stream.remove_auth_stream(world)
      }
    end
  end

  # world作成
  world_setting(:worldon, _('Mastodonアカウント(Worldon)')) do
    error_msg = nil
    while true
      if error_msg.is_a? String
        label error_msg
      end
      input 'インスタンスのドメイン', :domain

      result = await_input
      domain = result[:domain]

      instance = PM::Instance.load(domain)
      if instance.nil?
        error_msg = "#{domain} インスタンスへの接続に失敗しました。やり直してください。"
      else
        break
      end
    end

    label 'Webページにアクセスして表示された認証コードを入力して、次へボタンを押してください。'
    link instance.authorize_url
    input '認証コード', :authorization_code
    result = await_input
    resp = PM::API.call(:post, domain, '/oauth/token',
                                     client_id: instance.client_key,
                                     client_secret: instance.client_secret,
                                     grant_type: 'authorization_code',
                                     redirect_uri: 'urn:ietf:wg:oauth:2.0:oob',
                                     code: result[:authorization_code]
                                    )
    token = resp[:access_token]

    resp = PM::API.call(:get, domain, '/api/v1/accounts/verify_credentials', token)
    if resp.has_key?(:error)
      Deferred.fail(resp[:error])
    end

    screen_name = resp[:acct] + '@' + domain
    resp[:acct] = screen_name
    account = PM::Account.new(resp)
    world = PM::World.new(
      id: screen_name,
      slug: screen_name,
      domain: domain,
      access_token: token,
      account: account
    )
    world.update_mutes!

    label '認証に成功しました。このアカウントを追加しますか？'
    label('アカウント名：' + screen_name)
    label('ユーザー名：' + resp[:display_name])
    world
  end
end
