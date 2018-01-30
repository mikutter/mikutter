require 'json'
require_relative 'websocket-client-simple-patch'
require_relative 'model'

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
          data = JSON.parse(event.data, symbolize_names: true)
          #pp data
          if data[:event] == 'update'
            payload = JSON.parse(data[:payload], symbolize_names: true)
            Plugin.call :extract_receive_message, datasource_slug, Plugin::Worldon::Status.build(domain, [payload])
          elsif data[:event] == 'delete'
            # 消す必要ある？
          elsif data[:event] == 'notification'
            # TODO: 通知対応
          end
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
            ws: nil,
          }
          @@streams[datasource_slug][:ws] = ws
        }

        notice "Worldon::Stream.start #{datasource_slug} done"
      end


      # FTL・LTLのdatasource追加＆開始
      def init_instance_stream (domain)
        instance = Instance.load(domain)

        Instance.add_datasources(domain)

        ftl_slug = Instance.datasource_slug(domain, :federated)
        ltl_slug = Instance.datasource_slug(domain, :local)

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
          Stream.kill Instance.datasource_slug(domain, :federated)
          Stream.kill Instance.datasource_slug(domain, :local)
          Instance.remove_datasources(domain)
        end
      end

      # HTL・通知のdatasource追加＆開始
      def init_auth_stream (world)
        lists = world.get_lists!

        Plugin[:worldon].filter_extract_datasources do |dss|
          instance = Instance.load(world.domain)
          datasources = { world.datasource_slug(:home) => "#{world.slug}(Worldon)/ホームタイムライン" }
          if lists.is_a? Array
            lists.each do |l|
              slug = world.datasource_slug(:list, l[:id])
              datasources[slug] = "#{world.slug}(Worldon)/リスト/#{l[:title]}"
            end
          else
            warn '[worldon] failed to get lists:' + lists['error'].to_s
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
