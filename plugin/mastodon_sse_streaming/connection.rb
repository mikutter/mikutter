# frozen_string_literal: true

require_relative 'client'
require_relative 'cooldown_time'

module Plugin::MastodonSseStreaming
  module ConnectionType
    class AbstractType
      attr_reader :domain
      attr_reader :uri

      def initialize(domain:, endpoint:)
        @domain = domain.freeze
        @uri = Diva::URI.new('https://%{domain}/api/v1/streaming/%{endpoint}' % {
                              domain:   domain,
                              endpoint: endpoint,
                            })
      end

      def params; {} end
    end

    class BaseType < AbstractType; end
    class ListType < AbstractType
      attr_reader :list_id

      def initialize(domain:, list_id:)
        @list_id = list_id
        super(domain: domain, endpoint: 'list')
      end

      def params
        { list: @list_id }
      end
    end
    module MediaType
      def params
        { **super, only_media: true }
      end
    end

    def self.create(domain:, stream_type:, list_id:)
      case stream_type
      when 'user', 'public', 'direct'
        BaseType.new(domain: domain, endpoint: stream_type)
      when 'public:local'
        BaseType.new(domain: domain, endpoint: 'public/local')
      when 'list'
        ListType.new(domain: domain, list_id: list_id)
      when %r[:media\z]
        *rest, _ = stream_type.split(':')
        create(
          domain: domain,
          stream_type: rest.join(':'),
          list_id: list_id
        ).extend(MediaType)
      end
    end
  end

  class Connection

    attr_reader :stream_slug
    attr_reader :connection_type
    attr_reader :token

    def initialize(stream_slug:, token:, connection_type:)
      @stream_slug = stream_slug
      @token = token
      @connection_type = connection_type
      @thread = nil
      @cooldown_time = Plugin::MastodonSseStreaming::CooldownTime.new
      start
    end

    def domain
      connection_type.domain
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
