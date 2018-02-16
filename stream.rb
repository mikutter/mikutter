require 'json'
require_relative 'websocket-client-simple-patch'
require_relative 'model/model'

module Plugin::Worldon
  class Stream
    @@streams = {}
    @@mutex = Thread::Mutex.new

    class << self
      def datasources
        ret = nil
        @@mutex.synchronize {
          ret = @@streams.keys.dup
        }
        ret
      end

      def kill(datasource_slug)
        ws = nil
        @@mutex.synchronize {
          if !@@streams.has_key? datasource_slug
            return
          end
          ws = @@streams[datasource_slug][:ws]
          @@streams.delete(datasource_slug)
        }
        ws.close
        notice "Worldon::Stream.kill #{datasource_slug} done"
      end

      def killall
        wss = []
        @@mutex.synchronize {
          @@streams.each do |key, value|
            wss.push value[:ws]
          end
          @@streams = {}
        }
        wss.each do |ws|
          ws.close
        end
        notice "Worldon::Stream.killall done"
      end

      def restart_all
        settings = {}
        wss = []
        @@mutex.synchronize {
          @@streams.each do |datasource_slug, hash|
            settings[datasource_slug] = {
              domain: hash[:domain],
              type: hash[:type],
              access_token: hash[:access_token],
              list_id: hash[:list_id],
            }
            wss.push hash[:ws]
          end
          @@streams = {}
        }
        wss.each do |ws|
          ws.close
        end
        settings.each do |datasource_slug, hash|
          Plugin.call(:worldon_start_stream, hash[:domain], hash[:type], datasource_slug, hash[:token], hash[:list_id])
        end
      end

      def start(domain, type, datasource_slug, access_token = nil, list_id = nil)
        url = 'wss://' + domain + '/api/v1/streaming?stream=' + type
        if !access_token.nil?
          url += '&access_token=' + access_token
        end
        if type == 'list'
          url += '&list=' + list_id.to_s
        end

        ws = WebSocket::Client::Simple.connect(url)

        ws.on :open do
          notice "#{datasource_slug} start streaming in Worldon"
        end

        ws.on :message do |event|
          Thread.new {
            Stream.message_handler(domain, datasource_slug, access_token, event)
          }
        end

        ws.on :close do |event|
          warn "websocket closed ("+domain+","+type+","+(list_id.to_s)+")"
          restart = false
          @@mutex.synchronize {
            if @@streams.has_key? datasource_slug
              restart = true
            end
          }
          if restart
            sleep 3 # TODO: 再接続待ち戦略
            Plugin.call(:worldon_start_stream, domain, type, datasource_slug, access_token, list_id)
          end
        end

        @@mutex.synchronize {
          @@streams[datasource_slug] = {
            domain: domain,
            type: type,
            access_token: access_token,
            list_id: list_id,
            ws: ws,
          }
        }

        notice "Worldon::Stream.start #{datasource_slug} done"
      end

      def stream_world(domain, access_token)
        Enumerator.new{|y|
          Plugin.filtering(:worldon_worlds, nil).first
        }.select{|world|
          world.domain == domain && world.access_token == access_token
        }.first
      end

      def message_handler(domain, datasource_slug, access_token, event)
        data = JSON.parse(event.data, symbolize_names: true)
        #pp data
        if data[:event] == 'update'
          update_handler(domain, datasource_slug, access_token, data)
        elsif data[:event] == 'delete'
          # 消す必要ある？
          # pawooは一定時間後（1分～7日後）に自動消滅するtootができる拡張をしている。
          # また、手動で即座に消す人もいる。
          # これは後からアクセスすることはできないがTLに流れてきたものは、
          # フォローした人々には見えている、という前提があるように思う。
          # だから消さないよ。
        elsif data[:event] == 'notification'
          notification_handler(domain, access_token, data)
        else
          # 未知のevent
          warn 'unknown stream event'
          pp data
          $stdout.flush
        end
      end

      def update_handler(domain, datasource_slug, access_token, data)
        payload = JSON.parse(data[:payload], symbolize_names: true)
        status = Plugin::Worldon::Status.build(domain, [payload]).first
        Plugin.call(:extract_receive_message, datasource_slug, [status])
        Plugin.call(:worldon_appear_toots, [status])
        world = stream_world(domain, access_token)
        Plugin.call(:update, world, [status])
        if (status&.reblog).is_a?(Status)
          Plugin.call(:retweet, [status])
          world = status.to_me_world
          if !world.nil?
            Plugin.call(:mention, world, [status])
          end
        end
      end

      def notification_handler(domain, access_token, data)
        payload = JSON.parse(data[:payload], symbolize_names: true)

        case payload[:type]
        when 'mention'
          status = Plugin::Worldon::Status.build(domain, [payload[:status]]).first
          world = status.to_me_world
          if !world.nil?
            Plugin.call(:mention, world, [status])
          end

        when 'reblog'
          user = Plugin::Worldon::Account.new payload[:account]
          status_hash = payload[:status]
          reblog_hash = Marshal.load(Marshal.dump(status_hash))
          status = Plugin::Worldon::Status.build(domain, [status_hash]).first
          reblog = Plugin::Worldon::Status.build(domain, [reblog_hash]).first
          status.id = payload[:id]
          status[:retweet] = status.reblog = reblog
          status[:user] = status.account = user
          status.created_at = Time.parse(payload[:created_at]).localtime
          #puts "\n\n\n\nreblog:\n"
          #pp reblog
          #puts "\n\n\n\n"
          Plugin.call(:worldon_appear_toots, [status])
          Plugin.call(:retweet, [status])
          world = status.to_me_world
          if !world.nil?
            Plugin.call(:mention, world, [status])
          end

        when 'favourite'
          user = Plugin::Worldon::Account.new payload[:account]
          status = Plugin::Worldon::Status.build(domain, [payload[:status]]).first
          world = status.from_me_world
          if !world.nil?
            Plugin.call(:favorite, world, user, status)
          end

        when 'follow'
          user = Plugin::Worldon::Account.new payload[:account]
          world = stream_world(domain, access_token)
          if !world.nil?
            Plugin.call(:followers_created, world, [user])
          end

        else
          # 未知の通知
          warn 'unknown notification'
          pp data
          $stdout.flush
        end
      end

      # FTL・LTLのdatasource追加＆開始
      def init_instance_stream (domain)
        return if !UserConfig[:worldon_enable_streaming]

        instance = Instance.load(domain)

        Instance.add_datasources(domain)

        ftl_slug = Instance.datasource_slug(domain, :federated)
        ltl_slug = Instance.datasource_slug(domain, :local)

        # ストリーム開始
        Plugin.call(:worldon_start_stream, domain, 'public', ftl_slug)
        Plugin.call(:worldon_start_stream, domain, 'public:local', ltl_slug)
      end

      # FTL・LTLの終了
      def remove_instance_stream (domain)
        Stream.kill Instance.datasource_slug(domain, :federated)
        Stream.kill Instance.datasource_slug(domain, :local)
        Instance.remove_datasources(domain)
      end

      # HTL・通知のdatasource追加＆開始
      def init_auth_stream (world)
        return if !UserConfig[:worldon_enable_streaming]

        lists = world.get_lists!

        Plugin[:worldon].filter_extract_datasources do |dss|
          instance = Instance.load(world.domain)
          datasources = { world.datasource_slug(:home) => "Mastodonホームタイムライン(Worldon)/#{world.slug}" }
          if lists.is_a? Array
            lists.each do |l|
              slug = world.datasource_slug(:list, l[:id])
              datasources[slug] = "Mastodonリスト(Worldon)/#{world.slug}/#{l[:title]}"
            end
          else
            warn '[worldon] failed to get lists:' + lists['error'].to_s
          end
          [datasources.merge(dss)]
        end

        # ストリーム開始
        Plugin.call(:worldon_start_stream, world.domain, 'user', world.datasource_slug(:home), world.access_token)

        if lists.is_a? Array
          lists.each do |l|
            id = l[:id].to_i
            slug = world.datasource_slug(:list, id)
            Plugin.call(:worldon_start_stream, world.domain, 'list', world.datasource_slug(:list, id), world.access_token, id)
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
          Stream.kill slug
        end

        Plugin[:worldon].filter_extract_datasources do |datasources|
          slugs.each do |slug|
            datasources.delete slug
          end
          [datasources]
        end
      end

    end # Stream.class

  end # Stream
end # Plugin::Worldon
