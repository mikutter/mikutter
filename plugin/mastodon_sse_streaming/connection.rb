# frozen_string_literal: true

require_relative 'client'
require_relative 'cooldown_time'

module Plugin::MastodonSseStreaming
  class Connection

    attr_reader :connection_type

    def initialize(connection_type:)
      type_strict connection_type => tcor(Plugin::Mastodon::SSEPublicType, Plugin::Mastodon::SSEAuthorizedType)
      @connection_type = connection_type
      @thread = nil
      @cooldown_time = Plugin::MastodonSseStreaming::CooldownTime.new
      start
    end

    def domain
      connection_type.server.domain
    end

    def stream_slug
      connection_type.datasource_slug
    end

    def token
      connection_type.token
    end

    def stop
      @thread.kill
    end

    private

    def start
      @thread = Thread.new do
        loop do
          connect
          @cooldown_time.sleep
        end
      ensure
        @cooldown_time.sleep
        start
      end
    end

    def connect
      parser = Plugin::MastodonSseStreaming::Parser.new(self)
      client = HTTPClient.new
      notice "connect #{connection_type.uri.to_s}"
      response = client.request(:get, connection_type.uri.to_s, connection_type.params, {}, headers) do |fragment|
        @cooldown_time.reset
        parser << fragment
      end
      Plugin.call(:mastodon_stop_stream, stream_slug) if response.status == 410
      @cooldown_time.status_code(response.status)
    rescue => exc
      @cooldown_time.client_error
      error exc
    end

    def headers
      if token
        { 'Authorization' => 'Bearer %{token}' % {token: token} }
      else
        {}
      end
    end
  end
end
