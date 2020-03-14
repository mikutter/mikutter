require_relative 'connection'

Plugin.create(:mastodon_sse_streaming) do
  # ストリーム開始＆直近取得イベント
  # Plugin::Mastodon::SSEAuthorizedType または Plugin::Mastodon::SSEAuthorizedTypeを渡す
  defevent :mastodon_start_stream, prototype: [Diva::Model]

  connections = {}

  # TODO: 接続時に判断するのではなく、データソースの購読状況を購読してconnectionを制御する
  on_mastodon_start_stream do |sse_type|
    next unless UserConfig[:mastodon_enable_streaming]

    connections[sse_type] ||= Plugin::MastodonSseStreaming::Connection.new(
      connection_type: sse_type
    )
  end

  # TODO: slug -> SSEAuthorizedType
  on_mastodon_stop_stream do |slug|
    connections.delete(slug)&.stop
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

    UserConfig[:mastodon_instances].each do |domain, _|
      Plugin::Mastodon::Instance.add_ifn(domain).next do |server|
        Plugin.call(:mastodon_init_instance_stream, server)
      end
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
      Plugin::Mastodon::Instance.add_ifn(domain).next do |server|
        Plugin.call(:mastodon_init_instance_stream, server)
      end
    end
  end

  on_mastodon_init_instance_stream do |server|
    # ストリーム開始
    Plugin.call(:mastodon_start_stream, server.sse.public)
    Plugin.call(:mastodon_start_stream, server.sse.public(only_media: true))
    Plugin.call(:mastodon_start_stream, server.sse.public_local)
    Plugin.call(:mastodon_start_stream, server.sse.public_local(only_media: true))
  end

  on_mastodon_remove_instance_stream do |domain|
    Plugin.call(:mastodon_stop_stream, Plugin::Mastodon::Instance.datasource_slug(domain, :federated))
    Plugin.call(:mastodon_stop_stream, Plugin::Mastodon::Instance.datasource_slug(domain, :local))
    Plugin::Mastodon::Instance.remove_datasources(domain)
  end

  on_mastodon_init_auth_stream do |world|
    Plugin.call(:mastodon_start_stream, world.sse.user)
    Plugin.call(:mastodon_start_stream, world.sse.direct)
    world.get_lists.next { |lists|
      lists.each do |l|
        Plugin.call(:mastodon_start_stream, world.sse.list(list_id: l[:id].to_i, title: l[:title]))
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
    end
  end

  on_mastodon_sse_on_update do |connection, json|
    update_handler(connection, JSON.parse(json, symbolize_names: true))
  end

  on_mastodon_sse_on_notification do |connection, json|
    notification_handler(connection, JSON.parse(json, symbolize_names: true))
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

  on_mastodon_sse_kill_all do |event_sym|
    connections.values.each(&:stop)
    connections = {}

    Plugin.call(event_sym) if event_sym
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

  def update_handler(connection_type, payload)
    status = Plugin::Mastodon::Status.build(connection_type.domain, [payload]).first
    return unless status

    Plugin.call(:extract_receive_message, connection_type.stream_slug, [status])
    Plugin.call(:update, stream_world(connection_type.domain, connection_type.token), [status])
    if status.reblog?
      Plugin.call(:share, status.user, status.reblog)
      status.to_me_world&.yield_self do |world|
        Plugin.call(:mention, world, [status])
      end
    end
  end

  def notification_handler(connection_type, payload)
    domain = connection_type.domain

    case payload[:type]
    when 'mention'
      status = Plugin::Mastodon::Status.build(domain, [payload[:status]]).first
      return unless status
      Plugin.call(:extract_receive_message, connection_type.stream_slug, [status])
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
      stream_world(domain, connection_type.token)&.yield_self do |world|
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
end
