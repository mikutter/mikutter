# frozen_string_literal: true

module Plugin::Mastodon
  class SSEPublicType < Diva::Model
    field.has :server, Plugin::Mastodon::Instance, required: true

    attr_reader :datasource_slug
    attr_reader :title
    attr_reader :perma_link

    def token
      nil
    end

    def public(only_media: false)
      params[:only_media] = only_media
      @datasource_slug =
        if only_media
          "mastodon-#{server.domain}-federated-media".to_sym
        else
          "mastodon-#{server.domain}-federated".to_sym
        end
      set_endpoint('public')
    end

    def public_local(only_media: false)
      params[:only_media] = only_media
      @datasource_slug =
        if only_media
          "mastodon-#{server.domain}-local-media".to_sym
        else
          "mastodon-#{server.domain}-local".to_sym
        end
      set_endpoint('public_local')
    end

    def set_endpoint(endpoint)
      @perma_link = Diva::URI.new('https://%{domain}/api/v1/streaming/%{endpoint}' % {
                             domain:   server.domain,
                             endpoint: endpoint,
                           })
      self
    end

    def params
      @params ||= {}
    end
  end
end
