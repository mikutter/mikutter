require 'httpclient'

module Plugin::MastodonSseStreaming
  class Parser
    attr_reader :buffer

    #
    # @param [Plugin::Mastodon::SSEAuthorizedType|Plugin::Mastodon::SSEPublicType] connection_type
    #
    def initialize(connection_type)
      @connection_type = connection_type
      @buffer = ''
      @event = @data = nil
    end

    def <<(str)
      @buffer += str
      consume
      self
    end

    def consume
      # 改行で分割
      *lines, @buffer = @buffer.split("\n", -1)
      last_type = nil

      # SSEのメッセージパース
      lines.select { |l|
        !l.start_with?(':')     # コメント除去
      }.map { |l|
        l.split(": ", 2)
      }.select { |key, _|
        # これら以外のフィールドは無視する（nilは空行検出のため）
        # cf. https://developer.mozilla.org/ja/docs/Server-sent_events/Using_server-sent_events#Event_stream_formata
        ['event', 'data', 'id', 'retry', nil].include?(key)
      }.each do |type, payload|
        if last_type == 'data' && type != 'data'
          unless @event
            @event = ''
          end
          Plugin.call(:sse_message_type_event, @connection_type, @event, @data)
          Plugin.call(:"mastodon_sse_on_#{@event}", @connection_type, @data)  # 利便性のため
          @event = @data = nil  # 一応リセット
        end

        case type
        when nil
          # 空行→次の処理単位へ移動
          @event = @data = nil
          last_type = nil
        when 'event'
          # イベントタイプ指定
          @event = payload
          last_type = 'event'
        when 'data'
          # データ本体
          if @data.empty?
            @data = ''
          else
            @data += "\n"
          end
          @data += payload
          last_type = 'data'
        when 'id'
          # EventSource オブジェクトの last event ID の値に設定する、イベント ID です。
          Plugin.call(:sse_message_type_id, @connection_type, id)
          @event = @data = nil  # 一応リセット
          last_type = 'id'
        when 'retry'
          # イベントの送信を試みるときに使用する reconnection time です。[What code handles this?]
          # これは整数値であることが必要で、reconnection time をミリ秒単位で指定します。
          # 整数値ではない値が指定されると、このフィールドは無視されます。
          #
          # [What code handles this?]じゃねんじゃｗ
          if payload =~ /\A-?(0|[1-9][0-9]*)\Z/
            Plugin.call(:sse_message_type_retry, @connection_type, payload.to_i)
          end
          @event = @data = nil  # 一応リセット
          last_type = 'retry'
        end
      end
    end
  end
end
