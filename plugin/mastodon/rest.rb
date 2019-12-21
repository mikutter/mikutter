Plugin.create(:mastodon) do
  settings = {}

  on_mastodon_request_rest do |slug|
    domain = settings[slug][:domain]
    path = settings[slug][:path]
    token = settings[slug][:token]
    params = settings[slug][:params]

    if !settings[slug][:last_id].nil?
      params[:since_id] = settings[slug][:last_id]
      params.delete(:limit)
    end

    request_statuses_since_previous_received(domain, path, token, params, settings[slug]).next{ |tl|
      Plugin.call :extract_receive_message, slug, tl if !tl.empty?

      tl.select(&:reblog?).each do |message|
        Plugin.call(:share, message.user, message.reblog)
      end
    }
  end

  on_mastodon_init_polling do |slug, domain, path, token, params|
    settings[slug] = {
      last_time: 0,
      last_id: nil,
      domain: domain,
      path: path,
      token: token,
      params: params,
    }

    Plugin.call(:mastodon_request_rest, slug)
  end

  on_mastodon_start_stream do |domain, type, slug, world, list_id|
    Thread.new {
      sleep(rand(10))

      # 直近の分を取得
      token = nil
      if mastodon?(world)
        token = world.access_token
      end
      params = { limit: 40 }
      path_base = '/api/v1/timelines/'
      case type
      when 'user'
        path = path_base + 'home'
      when 'public'
        path = path_base + 'public'
      when 'public:media'
        path = path_base + 'public'
        params[:only_media] = 1
      when 'public:local'
        path = path_base + 'public'
        params[:local] = 1
      when 'public:local:media'
        path = path_base + 'public'
        params[:local] = 1
        params[:only_media] = 1
      when 'list'
        path = path_base + 'list/' + list_id.to_s
      when 'direct'
        path = path_base + 'direct'
      end

      Plugin.call(:mastodon_init_polling, slug, domain, path, token, params)
    }
  end

  def request_statuses_since_previous_received(domain, path, token, params, settings_slug)
    Plugin::Mastodon::API.call(:get, domain, path, token, **params).next do |hashes|
      settings_slug[:last_time] = Time.now.to_i
      next if hashes.nil?
      statuses = Plugin::Mastodon::Status.build(domain, hashes.value)
      if statuses.size > 0
        settings_slug[:last_id] = statuses.map(&:id).max
      end
      # 2回目以降、limit=20いっぱいまで取れてしまった場合は続きの取得を行なう。
      if (!settings_slug[:last_id].nil? && statuses.size == 20)
        request_statuses_since_previous_received(domain, path, token, {**params, since_id: settings_slug[:last_id]}, settings_slug).next{ |tail|
          [*statuses, *tail]
        }
      else
        statuses
      end
    end
  end

  pinger = Proc.new do
    now = Time.now.to_i
    settings.each do |slug, setting|
      if (now - settings[slug][:last_time]) >= 60 * UserConfig[:mastodon_rest_interval]
        Plugin.call(:mastodon_request_rest, slug)
      end
    end
    Reserver.new(60, thread: SerialThread, &pinger)
  end

  Reserver.new(60, thread: SerialThread, &pinger)
end
