require 'json'
require_relative 'websocket-client-simple-patch'
require_relative 'model'

module Plugin::Worldon
  class Stream
    @@streams = {}
    @@mutex = Thread::Mutex.new

    class << self
      def show_datasources
        @@mutex.synchronize {
          pp @@streams.keys
        }
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
            Plugin.call :extract_receive_message, datasource_slug, Plugin::Worldon::Status.build([payload])
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
    end

  end
end
