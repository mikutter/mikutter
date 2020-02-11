require_relative 'client'

Plugin.create(:mastodon_sse_streaming) do
  # ストリーム開始＆直近取得イベント
  defevent :mastodon_start_stream, prototype: [String, String, String, Plugin::Mastodon::World, Integer]

  connections = {}

  on_mastodon_start_stream do |domain, type, slug, world, list_id|
    next unless UserConfig[:mastodon_enable_streaming]

    token = mastodon?(world) && world.access_token

    endpoint, params = sse_params(type, list_id: list_id)
    uri = Diva::URI.new('https://%{domain}/api/v1/streaming/%{endpoint}' % {
                          domain:   domain,
                          endpoint: endpoint,
                        })
    Plugin.call(:mastodon_sse_create, slug, :get, uri, sse_header(token: token), params, { domain: domain, type: type, token: token })
  end

  on_mastodon_stop_stream do |slug|
    Plugin.call(:mastodon_sse_kill_connection, slug)
  end

  # mikutterにとって自明に60秒以上過去となる任意の日時
  @last_all_restarted = Time.new(2007, 8, 31, 0, 0, 0, "+09:00")
  @waiting = false

  restarter = -> do
    if @waiting
      Plugin.call(:mastodon_sse_kill_all, :mastodon_start_all_streams)
      @last_all_restarted = Time.new
      @waiting = false
    end
    @waiting = false

    Delayer.new(delay: 60, &restarter)
  end

  on_mastodon_restart_all_streams do
    now = Time.new
    @waiting = true
    if (now - @last_all_restarted) >= 60
      restarter.call
    end
  end

  on_mastodon_start_all_streams do
    Plugin.collect(:mastodon_worlds).each do |world|
      Thread.new {
        world.update_mutes!
      }.next {
        Plugin.call(:mastodon_init_auth_stream, world)
      }.terminate(_('Mastodon: SSEコネクション確立前にエラーが発生しました'))
    end

    UserConfig[:mastodon_instances].each do |domain, setting|
      Plugin.call(:mastodon_init_instance_stream, domain)
    end
  end

  # サーバーを必要に応じて再起動
  on_mastodon_restart_instance_stream do |domain, retrieve = true|
    instance = Plugin::Mastodon::Instance.load(domain)
    if instance.retrieve != retrieve
      instance.retrieve = retrieve
      instance.store
    end

    Plugin.call(:mastodon_remove_instance_stream, domain)
    if retrieve
      Plugin.call(:mastodon_init_instance_stream, domain)
    end
  end

  on_mastodon_init_instance_stream do |domain|
    Plugin::Mastodon::Instance.add_datasources(domain)

    ftl_slug = Plugin::Mastodon::Instance.datasource_slug(domain, :federated)
    ftl_media_slug = Plugin::Mastodon::Instance.datasource_slug(domain, :federated_media)
    ltl_slug = Plugin::Mastodon::Instance.datasource_slug(domain, :local)
    ltl_media_slug = Plugin::Mastodon::Instance.datasource_slug(domain, :local_media)

    # ストリーム開始
    Plugin.call(:mastodon_start_stream, domain, 'public', ftl_slug) if datasource_used?(ftl_slug, true)
    Plugin.call(:mastodon_start_stream, domain, 'public:media', ftl_media_slug) if datasource_used?(ftl_media_slug)
    Plugin.call(:mastodon_start_stream, domain, 'public:local', ltl_slug) if datasource_used?(ltl_slug)
    Plugin.call(:mastodon_start_stream, domain, 'public:local:media', ltl_media_slug) if datasource_used?(ltl_media_slug)
  end

  on_mastodon_remove_instance_stream do |domain|
    Plugin.call(:mastodon_stop_stream, Plugin::Mastodon::Instance.datasource_slug(domain, :federated))
    Plugin.call(:mastodon_stop_stream, Plugin::Mastodon::Instance.datasource_slug(domain, :local))
    Plugin::Mastodon::Instance.remove_datasources(domain)
  end

  on_mastodon_init_auth_stream do |world|
    world.get_lists.next { |lists|
      filter_extract_datasources do |dss|
        datasources = {
          world.datasource_slug(:home) => _("Mastodonホームタイムライン(Mastodon)/%{acct}") % {acct: world.account.acct},
          world.datasource_slug(:direct) => _("Mastodon DM(Mastodon)/%{acct}") % {acct: world.account.acct},
        }
        lists.each do |l|
          slug = world.datasource_slug(:list, l[:id])
          datasources[slug] = _("Mastodonリスト(Mastodon)/%{acct}/%{title}") % {acct: world.account.acct, title: l[:title]}
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

      lists.each do |l|
        id = l[:id].to_i
        if datasource_used?(world.datasource_slug(:list, id))
          Plugin.call(:mastodon_start_stream, world.domain, 'list', world.datasource_slug(:list, id), world, id)
        end
      end
    }.terminate(_('Mastodon: SSEコネクション確立時にエラーが発生しました'))
  end

  on_mastodon_remove_auth_stream do |world|
    world.get_lists.next do |lists|
      slugs = [
        world.datasource_slug(:home),
        world.datasource_slug(:direct),
        *lists.map do |l|
          world.datasource_slug(:list, l[:id].to_i)
        end
      ]

      slugs.each do |slug|
        Plugin.call(:mastodon_stop_stream, slug)
      end

      # TODO: フィルタをdetachして消す
      filter_extract_datasources do |datasources|
        slugs.each do |slug|
          datasources.delete slug
        end
        [datasources]
      end
    end
  end

  on_mastodon_restart_sse_stream do |slug|
    Thread.new {
      connection, = Plugin.filtering(:mastodon_sse_connection, slug)
      next unless connection
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
    Plugin::Mastodon::Util.ppf response if Mopt.error_level >= 1

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

  on_mastodon_sse_connection_error do |slug, exception|
    Plugin.call(:mastodon_restart_sse_stream, slug)
  end

  on_mastodon_sse_on_update do |slug, json|
    data = JSON.parse(json, symbolize_names: true)
    update_handler(slug, data)
  end

  on_mastodon_sse_on_notification do |slug, json|
    data = JSON.parse(json, symbolize_names: true)
    notification_handler(slug, data)
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

  on_mastodon_sse_create do |slug, method, uri, headers = {}, params = {}, opts = {}|
    if connections.has_key? slug
      warn 'sse_client streaming duplicate'
      thread = connections[slug][:thread]
      connections.delete(slug)
      thread.kill
    end

    conv = []
    params.each do |key, val|
      if val.is_a? Array
        val.each do |v|
          conv << [key.to_s + '[]', v]
        end
      else
        conv << [key.to_s, val]
      end
    end

    query = {}
    body = {}

    case method
    when :get
      query = conv
    when :post
      body = conv
    end

    Plugin.call(:mastodon_sse_connection_opening, slug)
    client = HTTPClient.new

    thread = Thread.new do
      parser = Plugin::MastodonSseStreaming::Parser.new(self, slug)
      response = client.request(method, uri.to_s, query, body, headers) do |fragment|
        parser << fragment
      end
      if response.status != 200
        Plugin.call(:mastodon_sse_connection_failure, slug, response)
      end
      Plugin.call(:mastodon_sse_connection_closed, slug)
    rescue => e
      Plugin.call(:mastodon_sse_connection_error, slug, e)
      next
    end
    connections[slug] = {
      method: method,
      uri: uri,
      headers: headers,
      params: params,
      opts: opts,
      thread: thread,
    }

  rescue => e
    Plugin.call(:mastodon_sse_connection_error, slug, e)
    nil
  end

  on_mastodon_sse_kill_connection do |slug|
    if connections.has_key? slug
      thread = connections[slug][:thread]
      connections.delete(slug)
      thread.kill
    end
  end

  on_mastodon_sse_kill_all do |event_sym|
    connections.each do |_, hash|
      hash[:thread].kill
    end
    connections = {}

    Plugin.call(event_sym) if event_sym
  end

  filter_mastodon_sse_connection do |slug|
    [connections[slug]]
  end

  filter_mastodon_sse_connection_all do |_|
    [connections]
  end

  def datasource_used?(slug, include_all = false)
    return false unless UserConfig[:extract_tabs]
    UserConfig[:extract_tabs].any? do |setting|
      setting[:sources].any? do |ds|
        ds == slug || include_all && ds == :mastodon_appear_toots
      end
    end
  end

  def stream_world(domain, access_token)
    Plugin.collect(:mastodon_worlds).lazy.select{|world|
      world.domain == domain && world.access_token == access_token
    }.first
  end

  def update_handler(datasource_slug, payload)
    connection, = Plugin.filtering(:mastodon_sse_connection, datasource_slug)
    return unless connection
    domain = connection[:opts][:domain]
    access_token = connection[:opts][:token]
    status = Plugin::Mastodon::Status.build(domain, [payload]).first
    return unless status

    Plugin.call(:extract_receive_message, datasource_slug, [status])
    Plugin.call(:update, stream_world(domain, access_token), [status])
    if status.reblog?
      Plugin.call(:share, status.user, status.reblog)
      status.to_me_world&.yield_self do |world|
        Plugin.call(:mention, world, [status])
      end
    end
  end

  def notification_handler(datasource_slug, payload)
    connection, = Plugin.filtering(:mastodon_sse_connection, datasource_slug)
    return unless connection
    domain = connection[:opts][:domain]
    access_token = connection[:opts][:token]

    case payload[:type]
    when 'mention'
      status = Plugin::Mastodon::Status.build(domain, [payload[:status]]).first
      return unless status
      Plugin.call(:extract_receive_message, datasource_slug, [status])
      status.to_me_world&.yield_self do |world|
        Plugin.call(:mention, world, [status])
      end

    when 'reblog'
      Plugin.call(:share,
                  Plugin::Mastodon::Account.new(payload[:account]),
                  Plugin::Mastodon::Status.build(domain, [payload[:status]]).first)
    when 'favourite'
      user = Plugin::Mastodon::Account.new(payload[:account])
      status = Plugin::Mastodon::Status.build(domain, [payload[:status]]).first
      return unless status
      status.favorite_accts << user.acct
      status.set_modified(Time.now.localtime) if favorite_age?(user)
      if user && status
        world, = Plugin.filtering(:mastodon_current, nil)
        Plugin.call(:favorite, world, user, status) if world
      end

    when 'follow'
      user = Plugin::Mastodon::Account.new payload[:account]
      stream_world(domain, access_token)&.yield_self do |world|
        Plugin.call(:followers_created, world, [user])
      end

    when 'poll'
      status = Plugin::Mastodon::Status.build(domain, [payload[:status]]).first
      return unless status
      activity(:poll, _('投票が終了しました'), description: "#{status.uri}")

    else
      # 未知の通知
      warn 'unknown notification'
      Plugin::Mastodon::Util.ppf payload if Mopt.error_level >= 2
    end
  end

  def favorite_age?(user)
    if user.me?
      UserConfig[:favorited_by_myself_age]
    else
      UserConfig[:favorited_by_anyone_age]
    end
  end

  def sse_params(type, list_id:)
    case type
    when 'user', 'public', 'direct'
      return type, {}
    when 'public:local'
      return 'public/local', {}
    when 'list'
      return 'list', {list: list_id}
    when %r[:media\z]
      *path, _ = type.split(':')
      return path.join('/'), {only_media: true}
    end
  end

  def sse_header(token:)
    if token
      { 'Authorization' => 'Bearer %{token}' % {token: token} }
    else
      {}
    end
  end
end
