# frozen_string_literal: true

require_relative 'client'

module Plugin::MastodonSseStreaming
  class Connection
    COOLDOWN_NONE_DURATION = 0
    COOLDOWN_MIN_DURATION = 1
    COOLDOWN_MAX_DURATION = 64

    attr_reader :stream_slug
    attr_reader :method
    attr_reader :uri
    attr_reader :headers
    attr_reader :params           # TODO: paramsとoptsは名前何とかする
    attr_reader :opts

    def initialize(stream_slug:, method:, uri:, headers:, params:, opts:)
      @stream_slug = stream_slug
      @method = method
      @uri = uri
      @headers = headers
      @params = params
      @opts = opts
      @thread = nil
      @cooldown_time = COOLDOWN_NONE_DURATION
      start
    end

    def stop
      @thread.kill
    end

    private

    def start
      @thread ||= Thread.new do
        loop do
          connect
          unless @cooldown_time == COOLDOWN_NONE_DURATION
            warn "reconnect #{@cooldown_time}s later."
            sleep(@cooldown_time)
          end
        end
      end
    end

    def connect
      parser = Plugin::MastodonSseStreaming::Parser.new(Plugin[:mastodon_sse_streaming], stream_slug)
      client = HTTPClient.new
      response = client.request(method, uri.to_s, *get_query_and_body, headers) do |fragment|
        @cooldown_time = COOLDOWN_NONE_DURATION
        parser << fragment
      end
      case response.status
      when 200..300
        @cooldown_time = COOLDOWN_NONE_DURATION
      when 410                  # HTTP 410 Gone
        Plugin.call(:mastodon_sse_kill_connection, stream_slug)
        @cooldown_time = COOLDOWN_MAX_DURATION
      when 400..500
        cooldown_increase_client_error
      when 500..600
        cooldown_increase_server_error
      else
        cooldown_increase_client_error
      end
    rescue => exc
      cooldown_increase_client_error
      error exc
    end

    def cooldown_increase_client_error
      @cooldown_time = (@cooldown_time + 0.25)
                         .clamp(COOLDOWN_MIN_DURATION, COOLDOWN_MAX_DURATION)
    end

    def cooldown_increase_server_error
      @cooldown_time = (@cooldown_time * 2)
                         .clamp(COOLDOWN_MIN_DURATION, COOLDOWN_MAX_DURATION)
    end

    def get_query_and_body
      case method
      when :get
        return params_to_array_of_array.to_a, {}
      when :post
        return {}, params_to_array_of_array.to_a
      end
    end

    def params_to_array_of_array
      Enumerator.new do |yielder|
        params.each do |key, val|
          if val.is_a? Array
            val.each do |v|
              yielder << ["#{key}[]", v]
            end
          else
            yielder << [key, val]
          end
        end
      end
    end
  end
end
