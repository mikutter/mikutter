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
  # 各インスタンス向けアプリケーションキー用のストレージを確保しておく
  keys = at(:instances)
  if keys.nil?
    keys = Hash.new
    store(:instances, keys)
  end

  # ストリーム開始＆直近取得イベント
  defevent :worldon_start_stream, prototype: [String, String, String, String, Integer]

  # ストリーム開始＆直近取得
  on_worldon_start_stream do |domain, type, slug, token, list_id|
    # ストリーム開始
    Plugin::Worldon::Stream.start(domain, type, slug, token, list_id)

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
    tl = Plugin::Worldon::Status.build Plugin::Worldon::API.call(:get, domain, path, token, opts)
    Plugin.call :extract_receive_message, slug, tl
  end

  # FTL・LTLのdatasource追加＆開始
  def init_instance_stream (domain)
    instance = Plugin::Worldon::Instance.load(domain)

    Plugin::Worldon::Instance.add_datasources(domain)

    ftl_slug = Plugin::Worldon::Instance.datasource_slug(domain, :federated)
    ltl_slug = Plugin::Worldon::Instance.datasource_slug(domain, :local)

    if UserConfig[:realtime_rewind]
      # ストリーム開始
      Plugin.call(:worldon_start_stream, domain, 'public', ftl_slug)
      Plugin.call(:worldon_start_stream, domain, 'public:local', ltl_slug)
    end
  end

  # FTL・LTLの終了
  def remove_instance_stream (domain)
    worlds = Enumerator.new{|y|
      Plugin.filtering(:worlds, y)
    }.select{|world|
      world.class.slug == :worldon_for_mastodon
    }.select{|world|
      world.domain == domain
    }
    if worlds.empty?
      Plugin::Worldon::Stream.kill Plugin::Worldon::Instance.datasource_slug(domain, :federated)
      Plugin::Worldon::Stream.kill Plugin::Worldon::Instance.datasource_slug(domain, :local)
      Plugin::Worldon::Instance.remove_datasources(domain)
    end
  end

  # HTL・通知のdatasource追加＆開始
  def init_auth_stream (world)
    lists = world.get_lists!

    filter_extract_datasources do |dss|
      instance = Plugin::Worldon::Instance.load(world.domain)
      datasources = { world.datasource_slug(:home) => "#{world.slug}(Worldon)/ホームタイムライン" }
      if lists.is_a? Array
        lists.each do |l|
          slug = world.datasource_slug(:list, l[:id])
          datasources[slug] = "#{world.slug}(Worldon)/リスト/#{l[:title]}"
        end
      else
        warn '[worldon] failed to get lists:' + lists['error']
      end
      [datasources.merge(dss)]
    end

    if UserConfig[:realtime_rewind]
      # ストリーム開始
      Plugin.call(:worldon_start_stream, world.domain, 'user', world.datasource_slug(:home), world.access_token)
      #Plugin.call(:worldon_start_stream, world.domain, 'user:notification', world.datasource_slug(:notification), world.access_token)

      if lists.is_a? Array
        lists.each do |l|
          id = l[:id].to_i
          slug = world.datasource_slug(:list, id)
          Plugin.call(:worldon_start_stream, world.domain, 'list', world.datasource_slug(:list, id), world.access_token, id)
        end
      end
    end
  end

  # HTL・通知の終了
  def remove_auth_stream (world)
    slugs = []
    slugs.push world.datasource_slug(:home)
    #slugs.push world.datasource_slug(:notification)

    lists = world.get_lists!
    if lists.is_a? Array
      lists.each do |l|
        id = l[:id].to_i
        slugs.push world.datasource_slug(:list, id)
      end
    end

    slugs.each do |slug|
      Plugin::Worldon::Stream.kill slug
    end

    filter_extract_datasources do |datasources|
      slugs.each do |slug|
        datasources.delete slug
      end
      [datasources]
    end
  end


  # 終了時
  onunload do
    Plugin::Worldon::Stream.killall
  end

  # 起動時
  Delayer.new {
    worlds = Enumerator.new{|y|
      Plugin.filtering(:worlds, y)
    }.select{|world|
      world.class.slug == :worldon_for_mastodon
    }

    worlds.each do |world|
      init_auth_stream(world)
    end

    worlds.map{|world|
      world.domain
    }.to_a.uniq.each{|domain|
      init_instance_stream(domain)
    }
  }


  # spell系

  # ふぁぼ
  defevent :worldon_favorite, prototype: [Plugin::Worldon::World, Plugin::Worldon::Status]
  # ふぁぼる
  on_worldon_favorite do |world, status|
    # TODO: guiなどの他plugin向け通知イベントの調査
    status_id = Plugin::Worldon::API.get_local_status_id(world, status)
    Plugin::Worldon::API.call(:post, world.domain, '/api/v1/statuses/' + status_id.to_s + '/favourite', world.access_token)
    status.favourited = true
  end
  defspell(:favorite, :worldon_for_mastodon, :worldon_status,
           condition: -> (world, status) { !status.favorite? } # TODO: favorite?の引数にworldを取って正しく判定できるようにする
          ) do |world, status|
    Plugin.call(:worldon_favorite, world, status)
  end

  # ブーストイベント
  defevent :worldon_share, prototype: [Plugin::Worldon::World, Plugin::Worldon::Status]

  # ブースト
  on_worldon_share do |world, status|
    # TODO: guiなどの他plugin向け通知イベントの調査
    status_id = Plugin::Worldon::API.get_local_status_id(world, status)
    Plugin::Worldon::API.call(:post, world.domain, '/api/v1/statuses/' + status_id.to_s + '/reblog', world.access_token)
    status.reblogged = true
  end

  defspell(:share, :worldon_for_mastodon, :worldon_status,
           condition: -> (world, status) { !status.shared? } # TODO: shared?の引数にworldを取って正しく判定できるようにする
          ) do |world, status|
    Plugin.call(:worldon_share, world, status)
  end


  # world系

  # world追加
  on_world_create do |world|
    if world.class.slug == :worldon_for_mastodon
      Delayer.new {
        init_instance_stream(world.domain)
        init_auth_stream(world)
      }
    end
  end

  # world削除
  on_world_destroy do |world|
    if world.class.slug == :worldon_for_mastodon
      Delayer.new {
        remove_instance_stream(world.domain)
        remove_auth_stream(world)
      }
    end
  end

  # world作成
  world_setting(:worldon, _('Mastodonアカウント(Worldon)')) do
    input 'インスタンスのドメイン', :domain

    result = await_input
    domain = result[:domain]

    instance = Plugin::Worldon::Instance.load(domain)

    label 'Webページにアクセスして表示された認証コードを入力して、次へボタンを押してください。'
    link instance.authorize_url
    input '認証コード', :authorization_code
    result = await_input
    resp = Plugin::Worldon::API.call(:post, domain, '/oauth/token',
                                     client_id: instance.client_key,
                                     client_secret: instance.client_secret,
                                     grant_type: 'authorization_code',
                                     redirect_uri: 'urn:ietf:wg:oauth:2.0:oob',
                                     code: result[:authorization_code]
                                    )
    token = resp[:access_token]

    resp = Plugin::Worldon::API.call(:get, domain, '/api/v1/accounts/verify_credentials', token)
    if resp.has_key?(:error)
      Deferred.fail(resp[:error])
    end
    screen_name = resp[:acct] + '@' + domain
    resp[:acct] = screen_name
    account = Plugin::Worldon::Account.new_ifnecessary(resp)
    world = Plugin::Worldon::World.new(
      id: screen_name,
      slug: screen_name,
      domain: domain,
      access_token: token,
      account: account
    )

    label '認証に成功しました。このアカウントを追加しますか？'
    label('アカウント名：' + screen_name)
    label('ユーザー名：' + resp[:display_name])
    world
  end
end
