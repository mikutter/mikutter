require 'httpclient'

module Plugin::MastodonSseStreaming
  class Parser
    attr_reader :buffer

    #
    # @param [Plugin::Mastodon::SSEAuthorizedType|Plugin::Mastodon::SSEPublicType] connection_type
    #
    def initialize(connection, receiver)
      @connection = connection
      @buffer = ''
      @event = @data = nil
      @receiver = receiver
    end

    def <<(str)
      @buffer += str
      consume
      self
    end

    def event_received(event, payload)
      case event
      when 'update'       then update_handler(payload)
      when 'notification' then notification_handler(payload)
      end
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
          Plugin.call(:sse_message_type_event, @connection, @event, @data)
          Plugin.call(:"mastodon_sse_on_#{@event}", @connection, @data)  # 利便性のため
          event_received(@event, JSON.parse(@data, symbolize_names: true))
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
          @event = @data = nil  # 一応リセット
          last_type = 'id'
        when 'retry'
          # イベントの送信を試みるときに使用する reconnection time です。[What code handles this?]
          # これは整数値であることが必要で、reconnection time をミリ秒単位で指定します。
          # 整数値ではない値が指定されると、このフィールドは無視されます。
          #
          # [What code handles this?]じゃねんじゃｗ
          @event = @data = nil  # 一応リセット
          last_type = 'retry'
        end
      end
    end

    def update_handler(payload)
      message = Plugin::Mastodon::Status.build(@connection.domain, [payload]).first
      if message
        @receiver << message
        Plugin.call(:update, nil, [message])
      end
    end

    def mention_handler(status)
      message = Plugin::Mastodon::Status.build(@connection.domain, [status]).first
      if message
        @receiver << message
      end
    end

    def reblog_handler(account:, status:)
      Plugin.call(:share,
                  Plugin::Mastodon::Account.new(account),
                  Plugin::Mastodon::Status.build(@connection.domain, [status]).first)
    end

    def favorite_handler(account:, status:)
      message = Plugin::Mastodon::Status.build(@connection.domain, [status]).first
      user = Plugin::Mastodon::Account.new(account)
      if message
        message.favorite_accts << user.acct
        message.set_modified(Time.now.localtime) if favorite_age?(user)
        Plugin.call(:favorite, @connection.connection_type.world, user, message)
      end
    end

    def follow_handler(account)
      Plugin.call(:followers_created, @connection.connection_type.world,
                  [Plugin::Mastodon::Account.new(account)])
    end

    def poll_handler(status)
      message = Plugin::Mastodon::Status.build(@connection.domain, [status]).first
      if message
        activity(:poll, _('投票が終了しました'), description: "#{message.uri}")
      end
    end

    def notification_handler(payload)
      case payload[:type]
      when 'mention'   then mention_handler(payload[:status])
      when 'reblog'    then reblog_handler(**payload.slice(:account, :status))
      when 'favourite' then favorite_handler(**payload.slice(:account, :status))
      when 'follow'    then follow_handler(payload[:account])
      when 'poll'      then poll_handler(payload[:status])
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
end
