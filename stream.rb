require 'json'
require_relative 'websocket-client-simple-patch'
require_relative 'model'

module Plugin::Worldon
  class Stream
    @@streams = {}

    class << self
      def kill(datasource_slug)
        @@streams[datasource_slug][:ws].close
        @@streams.delete(datasource_slug)
      end

      def killall
        @@streams.each do |key, value|
          value[:ws].close
        end
        @@streams = {}
      end

      def start(domain, type, datasource_slug, access_token = nil, list_id = nil)
        @@streams[datasource_slug] = {
          domain: domain,
          type: type,
          access_token: access_token,
          list_id: list_id,
          ws: nil,
        }
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
          sleep 3 # TODO: 再接続待ち戦略
          Plugin.call(:worldon_start_stream, domain, type, datasource_slug, access_token, list_id)
        end

        @@streams[datasource_slug][:ws] = ws
      end
    end

  end
end
