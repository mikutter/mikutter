require_relative 'client'

Plugin.create(:mastodon_sse_streaming) do
  pm = Plugin::Mastodon

  # ストリーム開始＆直近取得イベント
  defevent :mastodon_start_stream, prototype: [String, String, String, pm::World, Integer]

  def datasource_used?(slug, include_all = false)
    return false if UserConfig[:extract_tabs].nil?
    UserConfig[:extract_tabs].any? do |setting|
      setting[:sources].any? do |ds|
        ds == slug || include_all && ds == :mastodon_appear_toots
      end
    end
  end

  on_mastodon_start_stream do |domain, type, slug, world, list_id|
    next if !UserConfig[:mastodon_enable_streaming]

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
      when 'public:media'
        uri = Diva::URI.new(base_url + 'public')
        params[:only_media] = true
      when 'public:local'
        uri = Diva::URI.new(base_url + 'public/local')
      when 'public:local:media'
        uri = Diva::URI.new(base_url + 'public/local')
        params[:only_media] = true
      when 'list'
        uri = Diva::URI.new(base_url + 'list')
        params[:list] = list_id
      when 'direct'
        uri = Diva::URI.new(base_url + 'direct')
      end

      headers = {}
      if token
        headers["Authorization"] = "Bearer " + token
      end

      Plugin.call(:mastodon_sse_create, slug, :get, uri, headers, params, domain: domain, type: type, token: token)
    }
  end

  on_mastodon_stop_stream do |slug|
    Plugin.call(:mastodon_sse_kill_connection, slug)
  end

  # mikutterにとって自明に60秒以上過去となる任意の日時
  @last_all_restarted = Time.new(2007, 8, 31, 0, 0, 0, "+09:00")
  @waiting = false

  restarter = Proc.new do
    if @waiting
      Plugin.call(:mastodon_sse_kill_all, :mastodon_start_all_streams)
      atomic {
        @last_all_restarted = Time.new
        @waiting = false
      }
    end
    atomic {
      @waiting = false
    }

    Reserver.new(60, &restarter)
  end

  on_mastodon_restart_all_streams do
    now = Time.new
    atomic {
      @waiting = true
    }
    if (now - @last_all_restarted) >= 60
      restarter.call
    end
  end

  on_mastodon_start_all_streams do
    worlds, = Plugin.filtering(:mastodon_worlds, nil)

    worlds.each do |world|
      Thread.new {
        world.update_mutes!
        Plugin.call(:mastodon_init_auth_stream, world)
      }
    end

    UserConfig[:mastodon_instances].map do |domain, setting|
      Plugin.call(:mastodon_init_instance_stream, domain)
    end
  end

  # サーバーを必要に応じて再起動
  on_mastodon_restart_instance_stream do |domain, retrieve = true|
    Thread.new {
      instance = pm::Instance.load(domain)
      if instance.retrieve != retrieve
        instance.retrieve = retrieve
        instance.store
      end

      Plugin.call(:mastodon_remove_instance_stream, domain)
      if retrieve
        Plugin.call(:mastodon_init_instance_stream, domain)
      end
    }
  end

  on_mastodon_init_instance_stream do |domain|
    Thread.new {
      pm::Instance.add_datasources(domain)

      ftl_slug = pm::Instance.datasource_slug(domain, :federated)
      ftl_media_slug = pm::Instance.datasource_slug(domain, :federated_media)
      ltl_slug = pm::Instance.datasource_slug(domain, :local)
      ltl_media_slug = pm::Instance.datasource_slug(domain, :local_media)

      # ストリーム開始
      Plugin.call(:mastodon_start_stream, domain, 'public', ftl_slug) if datasource_used?(ftl_slug, true)
      Plugin.call(:mastodon_start_stream, domain, 'public:media', ftl_media_slug) if datasource_used?(ftl_media_slug)
      Plugin.call(:mastodon_start_stream, domain, 'public:local', ltl_slug) if datasource_used?(ltl_slug)
      Plugin.call(:mastodon_start_stream, domain, 'public:local:media', ltl_media_slug) if datasource_used?(ltl_media_slug)
    }
  end

  on_mastodon_remove_instance_stream do |domain|
    Plugin.call(:mastodon_stop_stream, pm::Instance.datasource_slug(domain, :federated))
    Plugin.call(:mastodon_stop_stream, pm::Instance.datasource_slug(domain, :local))
    pm::Instance.remove_datasources(domain)
  end

  on_mastodon_init_auth_stream do |world|
    Thread.new {
      lists = world.get_lists!

      filter_extract_datasources do |dss|
        datasources = {
          world.datasource_slug(:home) => "Mastodonホームタイムライン(Mastodon)/#{world.account.acct}",
          world.datasource_slug(:direct) => "Mastodon DM(Mastodon)/#{world.account.acct}",
        }
        lists.to_a.each do |l|
          slug = world.datasource_slug(:list, l[:id])
          datasources[slug] = "Mastodonリスト(Mastodon)/#{world.account.acct}/#{l[:title]}"
        end
        [datasources.merge(dss)]
      end

      # ストリーム開始
      if datasource_used?(world.datasource_slug(:home), true)
        Plugin.call(:mastodon_start_stream, world.domain, 'user', world.datasource_slug(:home), world)
      end
      if datasource_used?(world.datasource_slug(:direct), true)
        Plugin.call(:mastodon_start_stream, world.domain, 'direct', world.datasource_slug(:direct), world)
      end

      lists.to_a.each do |l|
        id = l[:id].to_i
        if datasource_used?(world.datasource_slug(:list, id))
          Plugin.call(:mastodon_start_stream, world.domain, 'list', world.datasource_slug(:list, id), world, id)
        end
      end
    }
  end

  on_mastodon_remove_auth_stream do |world|
    slugs = []
    slugs.push world.datasource_slug(:home)
    slugs.push world.datasource_slug(:direct)

    lists = world.get_lists!
    lists.to_a.each do |l|
      id = l[:id].to_i
      slugs.push world.datasource_slug(:list, id)
    end

    slugs.each do |slug|
      Plugin.call(:mastodon_stop_stream, slug)
    end

    filter_extract_datasources do |datasources|
      slugs.each do |slug|
        datasources.delete slug
      end
      [datasources]
    end
  end

  on_mastodon_restart_sse_stream do |slug|
    Thread.new {
      connection, = Plugin.filtering(:mastodon_sse_connection, slug)
      if connection.nil?
        # 終了済み
        next
      end
      Plugin.call(:mastodon_sse_kill_connection, slug)

      sleep(rand(3..10))
      Plugin.call(:mastodon_sse_create, slug, :get, connection[:uri], connection[:headers], connection[:params], connection[:opts])
    }
  end

  on_mastodon_sse_connection_opening do |slug|
    notice "SSE: connection open for #{slug.to_s}"
  end

  on_mastodon_sse_connection_failure do |slug, response|
    error "SSE: connection failure for #{slug.to_s}"
    pm::Util.ppf response if Mopt.error_level >= 1

    if (response.status / 100) == 4
      # 4xx系レスポンスはリトライせず終了する
      Plugin.call(:mastodon_sse_kill_connection, slug)
    else
      Plugin.call(:mastodon_restart_sse_stream, slug)
    end
  end

  on_mastodon_sse_connection_closed do |slug|
    warn "SSE: connection closed for #{slug.to_s}"

    Plugin.call(:mastodon_restart_sse_stream, slug)
  end

  on_mastodon_sse_connection_error do |slug, e|
    error "SSE: connection error for #{slug.to_s}"
    pp e if Mopt.error_level >= 1

    Plugin.call(:mastodon_restart_sse_stream, slug)
  end

  on_mastodon_sse_on_update do |slug, json|
    Thread.new {
      data = JSON.parse(json, symbolize_names: true)
      update_handler(slug, data)
    }
  end

  on_mastodon_sse_on_notification do |slug, json|
    Thread.new {
      data = JSON.parse(json, symbolize_names: true)
      notification_handler(slug, data)
    }
  end

  on_mastodon_sse_on_delete do |slug, id|
    # 消す必要ある？
    # pawooは一定時間後（1分～7日後）に自動消滅するtootができる拡張をしている。
    # また、手動で即座に消す人もいる。
    # これは後からアクセスすることはできないがTLに流れてきたものは、
    # フォローした人々には見えている、という前提があるように思う。
    # だから消さないよ。
  end

  on_unload do
    Plugin.call(:mastodon_sse_kill_all)
  end

  def stream_world(domain, access_token)
    Enumerator.new{|y|
      Plugin.filtering(:mastodon_worlds, nil).first
    }.lazy.select{|world|
      world.domain == domain && world.access_token == access_token
    }.first
  end

  def update_handler(datasource_slug, payload)
    pm = Plugin::Mastodon

    connection, = Plugin.filtering(:mastodon_sse_connection, datasource_slug)
    return unless connection
    domain = connection[:opts][:domain]
    access_token = connection[:opts][:token]
    status = pm::Status.build(domain, [payload]).first
    return if status.nil?

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
    pm = Plugin::Mastodon

    connection, = Plugin.filtering(:mastodon_sse_connection, datasource_slug)
    return unless connection
    domain = connection[:opts][:domain]
    access_token = connection[:opts][:token]

    case payload[:type]
    when 'mention'
      status = pm::Status.build(domain, [payload[:status]]).first
      return if status.nil?
      Plugin.call(:extract_receive_message, datasource_slug, [status])
      world = status.to_me_world
      if !world.nil?
        Plugin.call(:mention, world, [status])
      end

    when 'reblog'
      user_id = payload[:account][:id]
      user_statuses = pm::API.call(:get, domain, "/api/v1/accounts/#{user_id}/statuses", access_token)
      if user_statuses.nil?
        error "Mastodon: ブーストStatusの取得に失敗"
        return
      end
      idx = user_statuses.value.index do |hash|
        hash[:reblog] && hash[:reblog][:uri] == payload[:status][:uri]
      end
      if idx.nil?
        error "Mastodon: ブーストStatusの取得に失敗（流れ速すぎ？）"
        return
      end

      status = pm::Status.build(domain, [user_statuses[idx]]).first
      return if status.nil?
      Plugin.call(:retweet, [status])
      world = status.to_me_world
      if world
        Plugin.call(:mention, world, [status])
      end

    when 'favourite'
      user = pm::Account.new(payload[:account])
      status = pm::Status.build(domain, [payload[:status]]).first
      return if status.nil?
      status.favorite_accts << user.acct
      world = status.from_me_world
      status.set_modified(Time.now.localtime) if UserConfig[:favorited_by_anyone_age] and (UserConfig[:favorited_by_myself_age] or world.user_obj != user)
      if user && status && world
        Plugin.call(:favorite, world, user, status)
      end

    when 'follow'
      user = pm::Account.new payload[:account]
      world = stream_world(domain, access_token)
      if !world.nil?
        Plugin.call(:followers_created, world, [user])
      end

    when 'poll'
      status = pm::Status.build(domain, [payload[:status]]).first
      return unless status
      activity(:poll, '投票が終了しました', description: "#{status.uri}")

    else
      # 未知の通知
      warn 'unknown notification'
      pm::Util.ppf payload if Mopt.error_level >= 2
    end
  end
end
