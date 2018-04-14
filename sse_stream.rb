require_relative 'sse_client'

Plugin.create(:worldon) do
  pm = Plugin::Worldon

  # ストリーム開始＆直近取得イベント
  defevent :worldon_start_stream, prototype: [String, String, String, pm::World, Integer]

  on_worldon_start_stream do |domain, type, slug, world, list_id|
    next if !UserConfig[:worldon_enable_streaming]

    Thread.new {
      sleep(rand(10))

      token = nil
      if world.is_a? pm::World
        token = world.access_token
      end

      base_url = 'https://' + domain + '/api/v1/streaming/'
      params = {}
      case type
      when 'user'
        uri = Diva::URI.new(base_url + 'user')
      when 'public'
        uri = Diva::URI.new(base_url + 'public')
      when 'public:local'
        uri = Diva::URI.new(base_url + 'public/local')
      when 'list'
        uri = Diva::URI.new(base_url + 'list')
        params[:list] = list_id
      end

      headers = {}
      if token
        headers["Authorization"] = "Bearer " + token
      end

      Plugin.call(:sse_create, slug, :get, uri, headers, params, domain: domain, type: type, token: token)
    }
  end

  on_worldon_stop_stream do |slug|
    Plugin.call(:sse_kill_connection, slug)
  end

  on_worldon_restart_all_stream do
    Plugin.call(:sse_kil_all)

    worlds, = Plugin.filtering(:worldon_worlds, nil)

    worlds.each do |world|
      Thread.new {
        world.update_mutes!
        Plugin.call(:worldon_init_auth_stream, world)
      }
    end

    UserConfig[:worldon_instances].map do |domain, setting|
      Plugin.call(:worldon_init_instance_stream, domain)
    end
  end

  # インスタンスストリームを必要に応じて再起動
  on_worldon_restart_instance_stream do |domain, retrieve = true|
    Thread.new {
      instance = pm::Instance.load(domain)
      if instance.retrieve != retrieve
        instance.retrieve = retrieve
        instance.store
      end

      Plugin.call(:worldon_remove_instance_stream, domain)
      if retrieve
        Plugin.call(:worldon_init_instance_stream, domain)
      end
    }
  end

  on_worldon_init_instance_stream do |domain|
    Thread.new {
      instance = pm::Instance.load(domain)

      pm::Instance.add_datasources(domain)

      ftl_slug = pm::Instance.datasource_slug(domain, :federated)
      ltl_slug = pm::Instance.datasource_slug(domain, :local)

      # ストリーム開始
      Plugin.call(:worldon_start_stream, domain, 'public', ftl_slug)
      Plugin.call(:worldon_start_stream, domain, 'public:local', ltl_slug)
    }
  end

  on_worldon_remove_instance_stream do |domain|
    Plugin.call(:worldon_stop_stream, pm::Instance.datasource_slug(domain, :federated))
    Plugin.call(:worldon_stop_stream, pm::Instance.datasource_slug(domain, :local))
    pm::Instance.remove_datasources(domain)
  end

  on_worldon_init_auth_stream do |world|
    Thread.new {
      lists = world.get_lists!

      filter_extract_datasources do |dss|
        instance = pm::Instance.load(world.domain)
        datasources = { world.datasource_slug(:home) => "Mastodonホームタイムライン(Worldon)/#{world.account.acct}" }
        lists.each do |l|
          slug = world.datasource_slug(:list, l[:id])
          datasources[slug] = "Mastodonリスト(Worldon)/#{world.account.acct}/#{l[:title]}"
        end
        [datasources.merge(dss)]
      end

      # ストリーム開始
      Plugin.call(:worldon_start_stream, world.domain, 'user', world.datasource_slug(:home), world)

      if lists.is_a? Array
        lists.each do |l|
          id = l[:id].to_i
          slug = world.datasource_slug(:list, id)
          Plugin.call(:worldon_start_stream, world.domain, 'list', world.datasource_slug(:list, id), world, id)
        end
      end
    }
  end

  on_worldon_remove_auth_stream do |world|
    slugs = []
    slugs.push world.datasource_slug(:home)

    lists = world.get_lists!
    if lists.is_a? Array
      lists.each do |l|
        id = l[:id].to_i
        slugs.push world.datasource_slug(:list, id)
      end
    end

    slugs.each do |slug|
      Plugin.call(:worldon_stop_stream, slug)
    end

    filter_extract_datasources do |datasources|
      slugs.each do |slug|
        datasources.delete slug
      end
      [datasources]
    end
  end

  on_worldon_restart_sse_stream do |slug|
    Thread.new {
      connection, = Plugin.filtering(:sse_connection, slug)
      if connection.nil?
        # 終了済み
        next
      end
      Plugin.call(:sse_kill_connection, slug)

      sleep(rand(3..10))
      Plugin.call(:sse_create, slug, :get, connection[:uri], connection[:headers], connection[:params], connection[:opts])
    }
  end

  on_sse_connection_opening do |slug|
    notice "SSE: connection open for #{slug.to_s}"
  end

  on_sse_connection_failure do |slug, response|
    error "SSE: connection failure for #{slug.to_s}"
    pp response if Mopt.error_level >= 1

    Plugin.call(:worldon_restart_sse_stream, slug)
  end

  on_sse_connection_closed do |slug|
    warn "SSE: connection closed for #{slug.to_s}"

    Plugin.call(:worldon_restart_sse_stream, slug)
  end

  on_sse_connection_error do |slug, e|
    error "SSE: connection error for #{slug.to_s}"
    pp e if Mopt.error_level >= 1

    Plugin.call(:worldon_restart_sse_stream, slug)
  end

  on_sse_on_update do |slug, json|
    Thread.new {
      data = JSON.parse(json, symbolize_names: true)
      update_handler(slug, data)
    }
  end

  on_sse_on_notification do |slug, json|
    Thread.new {
      data = JSON.parse(json, symbolize_names: true)
      notification_handler(slug, data)
    }
  end

  on_sse_on_delete do |slug, id|
    # 消す必要ある？
    # pawooは一定時間後（1分～7日後）に自動消滅するtootができる拡張をしている。
    # また、手動で即座に消す人もいる。
    # これは後からアクセスすることはできないがTLに流れてきたものは、
    # フォローした人々には見えている、という前提があるように思う。
    # だから消さないよ。
  end

  on_unload do
    Plugin.call(:sse_kill_all)
  end

  def stream_world(domain, access_token)
    Enumerator.new{|y|
      Plugin.filtering(:worldon_worlds, nil).first
    }.lazy.select{|world|
      world.domain == domain && world.access_token == access_token
    }.first
  end

  def update_handler(datasource_slug, payload)
    pm = Plugin::Worldon

    connection, = Plugin.filtering(:sse_connection, datasource_slug)
    domain = connection[:opts][:domain]
    access_token = connection[:opts][:token]
    status = pm::Status.build(domain, [payload]).first
    Plugin.call(:extract_receive_message, datasource_slug, [status])
    world = stream_world(domain, access_token)
    Plugin.call(:update, world, [status])
    if (status&.reblog).is_a?(pm::Status)
      Plugin.call(:retweet, [status])
      world = status.to_me_world
      if !world.nil?
        Plugin.call(:mention, world, [status])
      end
    end
  end

  def notification_handler(datasource_slug, payload)
    pm = Plugin::Worldon

    connection, = Plugin.filtering(:sse_connection, datasource_slug)
    domain = connection[:opts][:domain]
    access_token = connection[:opts][:token]

    case payload[:type]
    when 'mention'
      status = pm::Status.build(domain, [payload[:status]]).first
      world = status.to_me_world
      if !world.nil?
        Plugin.call(:mention, world, [status])
      end

    when 'reblog'
      user_id = payload[:account][:id]
      user_statuses = pm::API.call(:get, domain, "/api/v1/accounts/#{user_id}/statuses", access_token)
      if user_statuses.nil?
        error "Worldon: ブーストStatusの取得に失敗"
        return
      end
      if user_statuses.is_a?(Hash) && user_statuses[:array].is_a?(Array)
        user_statuses = user_statuses[:array]
      end
      idx = user_statuses.index do |hash|
        hash[:reblog] && hash[:reblog][:uri] == payload[:status][:uri]
      end
      if idx.nil?
        error "Worldon: ブーストStatusの取得に失敗（流れ速すぎ？）"
        return
      end

      status = pm::Status.build(domain, [user_statuses[idx]]).first
      Plugin.call(:retweet, [status])
      world = status.to_me_world
      if world
        Plugin.call(:mention, world, [status])
      end

    when 'favourite'
      user = pm::Account.new(payload[:account])
      status = pm::Status.build(domain, [payload[:status]]).first
      status.favorite_accts << user.acct
      world = status.from_me_world
      if user && status && world
        Plugin.call(:favorite, world, user, status)
      end

    when 'follow'
      user = pm::Account.new payload[:account]
      world = stream_world(domain, access_token)
      if !world.nil?
        Plugin.call(:followers_created, world, [user])
      end

    else
      # 未知の通知
      warn 'unknown notification'
      pp data if Mopt.error_level >= 2
      $stdout.flush
    end
  end
end
