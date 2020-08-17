# frozen_string_literal: true

module Plugin::Mastodon
  class SSEAuthorizedType < Diva::Model
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
      @title = Plugin[:mastodon]._("Mastodon/%{domain}/%{acct}/ホームタイムライン") % {domain: world.server.domain, acct: world.account.acct}
      set_endpoint('user')
    end

    def direct
      @datasource_slug = "mastodon-#{world.account.acct}-direct".to_sym
      @title = Plugin[:mastodon]._("Mastodon/%{domain}/%{acct}/ダイレクトメッセージ") % {domain: world.server.domain, acct: world.account.acct}
      set_endpoint('direct')
    end

    def list(list_id:, title:)
      params[:list] = list_id
      @datasource_slug = "mastodon-#{world.account.acct}-list-#{list_id}".to_sym
      @title = Plugin[:mastodon]._("Mastodon/%{domain}/%{acct}/%{title}") % {domain: world.server.domain, acct: world.account.acct, title: title}
      set_endpoint('list')
    end

    def public(only_media: false)
      params[:only_media] = only_media
      if only_media
        @datasource_slug = "mastodon-#{world.account.acct}-federated-media".to_sym
        @title = Plugin[:mastodon]._("Mastodon/%{domain}/%{acct}/連合タイムライン（メディアのみ）") % {domain: server.domain, acct: world.account.acct}
      else
        @datasource_slug = "mastodon-#{world.account.acct}-federated".to_sym
        @title = Plugin[:mastodon]._("Mastodon/%{domain}/%{acct}/連合タイムライン（全て）") % {domain: server.domain, acct: world.account.acct}
      end
      set_endpoint('public')
    end

    def public_local(only_media: false)
      params[:only_media] = only_media
      if only_media
        @datasource_slug = "mastodon-#{world.account.acct}-local-media".to_sym
        @title = Plugin[:mastodon]._("Mastodon/%{domain}/%{acct}/ローカルタイムライン（メディアのみ）") % {domain: server.domain, acct: world.account.acct}
      else
        @datasource_slug = "mastodon-#{world.account.acct}-local".to_sym
        @title = Plugin[:mastodon]._("Mastodon/%{domain}/%{acct}/ローカルタイムライン（全て）") % {domain: server.domain, acct: world.account.acct}
      end
      set_endpoint('public/local')
    end

    def set_endpoint(endpoint)
      @perma_link = Diva::URI.new('https://%{domain}/api/v1/streaming/%{endpoint}?%{query}' % {
                                    domain:   server.domain,
                                    endpoint: endpoint,
                                    query:    query,
                                  })
      self
    end

    def params
      @params ||= {}
    end

    def query
      params.map { |pair| pair.join('=') }.join('&')
    end
  end
end
