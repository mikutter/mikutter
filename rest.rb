Plugin.create(:worldon) do
  pm = Plugin::Worldon
  settings = {}

  on_worldon_request_rest do |slug|
    Thread.new {
      notice "Worldon: rest request for #{slug}"
      domain = settings[slug][:domain]
      path = settings[slug][:path]
      token = settings[slug][:token]
      params = settings[slug][:params]

      if !settings[slug][:last_id].nil?
        params[:since_id] = settings[slug][:last_id]
        params.delete(:limit)
      end

      tl = []
      begin
        hashes = pm::API.call(:get, domain, path, token, **params)
        settings[slug][:last_time] = Time.now.to_i
        next if hashes.nil?
        arr = hashes
        if (hashes.is_a?(Hash) && hashes[:array].is_a?(Array))
          arr = hashes[:array]
        end
        ids = arr.map{|hash| hash[:id].to_i }
        tl = pm::Status.build(domain, arr).concat(tl)

        notice "Worldon: REST取得数： #{ids.size} for #{slug}"
        if ids.size > 0
          settings[slug][:last_id] = params[:since_id] = ids.max
          # 2回目以降、limit=20いっぱいまで取れてしまった場合は続きの取得を行なう。
          if (!settings[slug][:last_id].nil? && ids.size == 20)
            notice "Worldon: 継ぎ足しREST #{slug}"
          end
        end
      end while (!settings[slug][:last_id].nil? && ids.size == 20)
      if domain.nil? && Mopt.error_level >= 2 # warn
        puts "on_worldon_start_stream domain is null #{type} #{slug} #{token.to_s} #{list_id.to_s}"
        pp tl.select{|status| status.domain.nil? }
        $stdout.flush
      end
      Plugin.call :extract_receive_message, slug, tl

      reblogs = tl.select{|status| status.reblog? }
      if !reblogs.empty?
        Plugin.call(:retweet, reblogs)
      end
    }
  end

  on_worldon_init_polling do |slug, domain, path, token, params|
    settings[slug] = {
      last_time: 0,
      last_id: nil,
      domain: domain,
      path: path,
      token: token,
      params: params,
    }

    Plugin.call(:worldon_request_rest, slug)
  end

  on_worldon_start_stream do |domain, type, slug, world, list_id|
    Thread.new {
      sleep(rand(10))

      # 直近の分を取得
      token = nil
      if world.is_a? pm::World
        token = world.access_token
      end
      params = { limit: 40 }
      path_base = '/api/v1/timelines/'
      case type
      when 'user'
        path = path_base + 'home'
      when 'public'
        path = path_base + 'public'
      when 'public:local'
        path = path_base + 'public'
        params[:local] = 1
      when 'list'
        path = path_base + 'list/' + list_id.to_s
      end

      Plugin.call(:worldon_init_polling, slug, domain, path, token, params)
    }
  end

  pinger = Proc.new do
    if !UserConfig[:worldon_enable_streaming]
      now = Time.now.to_i
      settings.each do |slug, setting|
        if (now - settings[slug][:last_time]) >= 60 * UserConfig[:worldon_rest_interval]
          Plugin.call(:worldon_request_rest, slug)
        end
      end
    end
    Reserver.new(60, thread: SerialThread, &pinger)
  end

  Reserver.new(60, thread: SerialThread, &pinger)
end
