# frozen_string_literal: true

require_relative 'client'
require_relative 'cooldown_time'

module Plugin::MastodonSseStreaming
  class Connection

    attr_reader :connection_type

    def initialize(connection_type:, receiver:)
      type_strict connection_type => tcor(Plugin::Mastodon::SSEPublicType, Plugin::Mastodon::SSEAuthorizedType)
      @connection_type = connection_type
      @thread = nil
      @cooldown_time = Plugin::MastodonSseStreaming::CooldownTime.new
      @receiver = receiver
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
      rescue Pluggaloid::NoReceiverError
        @thread = nil
      ensure
        if @thread == Thread.current
          @cooldown_time.sleep
          start
        end
      end
    end

    def connect
      parser = Plugin::MastodonSseStreaming::Parser.new(self, @receiver)
      client = HTTPClient.new
      notice "connect #{connection_type.perma_link.to_s}"
      response = client.request(:get, connection_type.perma_link.to_s, {}, {}, headers) do |fragment|
        @cooldown_time.reset
        parser << fragment
      end
      if response
        @cooldown_time.status_code(response.status_code)
      else
        @cooldown_time.client_error
      end
    rescue => exc
      error exc
      notice "disconnect #{response&.status} #{exc}"
      @cooldown_time.client_error
    rescue Exception => exc
      notice "disconnect #{response&.status} #{exc}"
      @cooldown_time.client_error
      raise
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
