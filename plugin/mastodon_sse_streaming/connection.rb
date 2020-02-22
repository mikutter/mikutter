# frozen_string_literal: true

require_relative 'client'
require_relative 'cooldown_time'

module Plugin::MastodonSseStreaming
  class Connection

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
      @cooldown_time = Plugin::MastodonSseStreaming::CooldownTime.new
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
          @cooldown_time.sleep
        end
      end
    end

    def connect
      parser = Plugin::MastodonSseStreaming::Parser.new(Plugin[:mastodon_sse_streaming], stream_slug)
      client = HTTPClient.new
      response = client.request(method, uri.to_s, *get_query_and_body, headers) do |fragment|
        @cooldown_time.reset
        parser << fragment
      end
      Plugin.call(:mastodon_sse_kill_connection, stream_slug) if response.status == 401
      @cooldown_time.status_code(response.status)
    rescue => exc
      @cooldown_time.client_error
      error exc
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
