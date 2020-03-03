# frozen_string_literal: true

module Plugin::Mastodon
  class RestAuthorizedType < Diva::Model
    field.has :world, Plugin::Mastodon::World, required: true

    attr_reader :datasource_slug
    attr_reader :title
    attr_reader :perma_link

    def server
      world.server
    end

    def token
      world.access_token
    end

    def user
      @datasource_slug = "mastodon-#{world.account.acct}-home".to_sym
      @title = Plugin[:mastodon]._("Mastodonホームタイムライン(Mastodon)/%{acct}") % {acct: world.account.acct}
      set_endpoint('home')
    end

    def direct
      @datasource_slug = "mastodon-#{world.account.acct}-direct".to_sym
      @title = Plugin[:mastodon]._("Mastodon DM(Mastodon)/%{acct}") % {acct: world.account.acct}
      set_endpoint('direct')
    end

    def list(list_id:, title:)
      # params[:list] = list_id
      @datasource_slug = "mastodon-#{world.account.acct}-list-#{list_id}".to_sym
      @title = Plugin[:mastodon]._("Mastodonリスト(Mastodon)/%{acct}/%{title}") % {acct: world.account.acct, title: title}
      set_endpoint("list/#{list_id}")
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
      params[:local] = 1
      @datasource_slug =
        if only_media
          "mastodon-#{server.domain}-local-media".to_sym
        else
          "mastodon-#{server.domain}-local".to_sym
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
