module Plugin::Worldon
  class Instance < Diva::Model
    register :worldon_instance, name: "Mastodonインスタンス(Worldon)"

    field.string :domain, required: true
    field.string :client_key, required: true
    field.string :client_secret, required: true

    class << self
      def datasource_slug(domain, type)
        case type
        when :local
          # ローカルTL
          "worldon-#{domain}-local".to_sym
        when :federated
          # 連合TL
          "worldon-#{domain}-federated".to_sym
        end
      end

      def add_datasources(domain)
        Plugin[:worldon].filter_extract_datasources do |dss|
          datasources = {
            datasource_slug(domain, :local) => "Mastodon公開タイムライン(Worldon)/ローカル/#{domain}",
            datasource_slug(domain, :federated) => "Mastodon公開タイムライン(Worldon)/連合/#{domain}",
          }
          [datasources.merge(dss)]
        end
      end

      def remove_datasources(domain)
        Plugin[:worldon].filter_extract_datasources do |datasources|
          datasources.delete datasource_slug(domain, :local)
          datasources.delete datasource_slug(domain, :federated)
          [datasources]
        end
      end

      def load(domain)
        keys = Plugin[:worldon].at(:instances)
        if keys.has_key?(domain)
          client_key = keys[domain][:client_key]
          client_secret = keys[domain][:client_secret]
        else
          resp = Plugin::Worldon::API.call(:post, domain, '/api/v1/apps',
                                           client_name: Plugin::Worldon::CLIENT_NAME,
                                           redirect_uris: 'urn:ietf:wg:oauth:2.0:oob',
                                           scopes: 'read write follow',
                                           website: Plugin::Worldon::WEB_SITE
                                          )
          client_key = resp[:client_id]
          client_secret = resp[:client_secret]
          add_datasources(domain)
        end
        instance = Instance.new(
          domain: domain,
          client_key: client_key,
          client_secret: client_secret
        )
        if !keys.has_key?(domain)
          instance.store
        end
        instance
      end
    end

    def store
      keys = Plugin[:worldon].at(:instances)
      if keys.nil?
        keys = Hash.new
      else
        keys = keys.dup
      end
      keys[domain] = { client_key: client_key, client_secret: client_secret }
      Plugin[:worldon].store(:instances, keys)
      self
    end

    def authorize_url
      params = URI.encode_www_form({
        scope: 'read write follow',
        response_type: 'code',
        redirect_uri: 'urn:ietf:wg:oauth:2.0:oob',
        client_id: client_key
      })
      'https://' + domain + '/oauth/authorize?' + params
    end
  end
end
