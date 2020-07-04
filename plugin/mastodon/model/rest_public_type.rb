# frozen_string_literal: true

module Plugin::Mastodon
  class RestPublicType < Diva::Model
    field.has :server, Plugin::Mastodon::Instance, required: true

    attr_reader :datasource_slug
    attr_reader :title
    attr_reader :perma_link

    def token
      nil
    end

    def public(only_media: false)
      params[:only_media] = only_media
      if only_media
        @datasource_slug = "mastodon-#{server.domain}-federated-media".to_sym
        @title = Plugin[:mastodon]._("Mastodon/%{domain}/連合タイムライン（メディアのみ）") % {domain: server.domain}
      else
        @datasource_slug = "mastodon-#{server.domain}-federated".to_sym
        @title = Plugin[:mastodon]._("Mastodon/%{domain}/連合タイムライン（全て）") % {domain: server.domain}
      end
      set_endpoint('public')
    end

    def public_local(only_media: false)
      params[:only_media] = only_media
      params[:local] = 1
      if only_media
        @datasource_slug = "mastodon-#{server.domain}-local-media".to_sym
        @title = Plugin[:mastodon]._("Mastodon/%{domain}/ローカルタイムライン（メディアのみ）") % {domain: server.domain}
      else
        @datasource_slug = "mastodon-#{server.domain}-local".to_sym
        @title = Plugin[:mastodon]._("Mastodon/%{domain}/ローカルタイムライン（全て）") % {domain: server.domain}
      end
      set_endpoint('public')
    end

    def set_endpoint(endpoint)
      @perma_link = Diva::URI.new('https://%{domain}/api/v1/timelines/%{endpoint}' % {
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
