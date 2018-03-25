require 'httpclient'

module Plugin::SseClient
  class Parser
    attr_reader :buffer

    def initialize(plugin, slug)
      @plugin = plugin
      @slug = slug
      @buffer = ''
      @records = []
      @event = @data = nil
    end

    def <<(str)
      @buffer += str
      consume
      self
    end

    def consume
      # 改行で分割
      lines = @buffer.split("\n", -1)
      @buffer = lines.pop  # 余りを次回に持ち越し

      # SSEのメッセージパース
      records = lines
        .select{|l| !l.start_with?(":") }  # コメント除去
        .map{|l|
          key, value = l.split(": ", 2)
          { key: key, value: value }
        }
        .select{|r|
          ['event', 'data', 'id', 'retry', nil].include?(r[:key])
          # これら以外のフィールドは無視する（nilは空行検出のため）
          # cf. https://developer.mozilla.org/ja/docs/Server-sent_events/Using_server-sent_events#Event_stream_format
        }
      @records.concat(records)

      last_type = nil
      while r = @records.shift
        if last_type == 'data' && r[:key] != 'data'
          if @event.nil?
            @event = ''
          end
          Plugin.call(:sse_message_type_event, @slug, @event, @data)
          Plugin.call(:"sse_on_#{@event}", @slug, @data)  # 利便性のため
          @event = @data = nil  # 一応リセット
        end

        case r[:key]
        when nil
          # 空行→次の処理単位へ移動
          @event = @data = nil
          last_type = nil
        when 'event'
          # イベントタイプ指定
          @event = r[:value]
          last_type = 'event'
        when 'data'
          # データ本体
          if @data.empty?
            @data = ''
          else
            @data += "\n"
          end
          @data += r[:value]
          last_type = 'data'
        when 'id'
          # EventSource オブジェクトの last event ID の値に設定する、イベント ID です。
          Plugin.call(:sse_message_type_id, @slug, id)
          @event = @data = nil  # 一応リセット
          last_type = 'id'
        when 'retry'
          # イベントの送信を試みるときに使用する reconnection time です。[What code handles this?]
          # これは整数値であることが必要で、reconnection time をミリ秒単位で指定します。
          # 整数値ではない値が指定されると、このフィールドは無視されます。
          #
          # [What code handles this?]じゃねんじゃｗ
          if r[:value] =~ /\A-?(0|[1-9][0-9]*)\Z/
            Plugin.call(:sse_message_type_retry, @slug, r[:value].to_i)
          end
          @event = @data = nil  # 一応リセット
          last_type = 'retry'
        else
        end
      end
    end
  end
end

Plugin.create(:sse_client) do
  pm = Plugin::Worldon

  connections = {}
  mutex = Thread::Mutex.new

  on_sse_create do |slug, method, uri, params = {}, headers = {}, **opts|
    begin
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

      Plugin.call(:sse_connection_opening, slug)
      client = HTTPClient.new

      thread = Thread.new {
        begin
          parser = Plugin::SseClient::Parser.new(self, slug)
          response = client.request(method, uri.to_s, query, body, headers) do |fragment|
            parser << fragment
          end

          case response.status
          when 200
          else
            Plugin.call(:sse_connection_failure, slug, response)
            error "ServerSentEvents connection failure"
            pp response if Mopt.error_level >= 1
            $stdout.flush
            next
          end

          Plugin.call(:sse_connection_closed, slug)

        rescue => e
          Plugin.call(:sse_connection_error, slug, e)
          error "ServerSentEvents connection error"
          pp e if Mopt.error_level >= 1
          $stdout.flush
          next
        end
      }
      mutex.synchronize {
        connections[slug] = {
          method: method,
          uri: uri,
          headers: headers,
          params: params,
          opts: opts,
          thread: thread,
        }
      }

    rescue => e
      Plugin.call(:sse_connection_error, slug, e)
      error "ServerSentEvents connection error"
      pp e if Mopt.error_level >= 1
      $stdout.flush
      nil
    end
  end

  on_sse_kill_connection do |slug|
    thread = nil
    mutex.synchronize {
      if connections.has_key? slug
        thread = connections[slug][:thread]
        connections.delete(slug)
      end
    }
    if thread
      thread.kill
    end
  end

  on_sse_kill_all do
    threads = []
    mutex.synchronize {
      connections.each do |slug, hash|
        threads << hash[:thread]
      end
      connections = {}
    }
    threads.each do |thread|
      thread.kill
    end
  end

  filter_sse_connection do |slug|
    [connections[slug]]
  end

  filter_sse_connection_all do |_|
    [connections[slug]]
  end
end
