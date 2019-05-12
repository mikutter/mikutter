module Plugin::Mastodon
  class Instance < Diva::Model
    register :mastodon_instance, name: "Mastodonサーバー"

    field.string :domain, required: true
    field.string :client_key, required: true
    field.string :client_secret, required: true
    field.bool :retrieve, required: true

    class << self
      def datasource_slug(domain, type)
        case type
        when :local
          # ローカルTL
          "mastodon-#{domain}-local".to_sym
        when :local_media
          # ローカルメディアTL
          "mastodon-#{domain}-local-media".to_sym
        when :federated
          # 連合TL
          "mastodon-#{domain}-federated".to_sym
        when :federated_media
          # 連合メディアTL
          "mastodon-#{domain}-federated-media".to_sym
        end
      end

      def add_datasources(domain)
        Plugin[:mastodon].filter_extract_datasources do |dss|
          datasources = {
            datasource_slug(domain, :local) => "Mastodon公開タイムライン/#{domain} ローカル",
            datasource_slug(domain, :local_media) => "Mastodon公開タイムライン/#{domain} ローカル（メディア）",
            datasource_slug(domain, :federated) => "Mastodon公開タイムライン/#{domain} 連合",
            datasource_slug(domain, :federated_media) => "Mastodon公開タイムライン/#{domain} 連合（メディア）",
          }
          [datasources.merge(dss)]
        end
      end

      def remove_datasources(domain)
        Plugin[:mastodon].filter_extract_datasources do |datasources|
          datasources.delete datasource_slug(domain, :local)
          datasources.delete datasource_slug(domain, :local_media)
          datasources.delete datasource_slug(domain, :federated)
          datasources.delete datasource_slug(domain, :federated_media)
          [datasources]
        end
      end

      def add(domain, retrieve = true)
        Delayer::Deferred.new.next {
          return nil if UserConfig[:mastodon_instances].has_key?(domain)

          Plugin::Mastodon::API.call(
            :post, domain, '/api/v1/apps',
            client_name: Plugin::Mastodon::CLIENT_NAME,
            redirect_uris: 'urn:ietf:wg:oauth:2.0:oob',
            scopes: 'read write follow',
            website: Plugin::Mastodon::WEB_SITE
          )
        }.next{ |resp|
          add_datasources(domain)

          self.new(
            domain: domain,
            client_key: resp[:client_id],
            client_secret: resp[:client_secret],
            retrieve: retrieve,
          ).store
        }
      end

      def add_ifn(domain, retrieve = true)
        Delayer::Deferred.new.next do
          self.load(domain) || +self.add(domain, retrieve)
        end
      end

      def load(domain)
        if UserConfig[:mastodon_instances][domain].nil?
          nil
        else
          self.new(
            domain: domain,
            client_key: UserConfig[:mastodon_instances][domain][:client_key],
            client_secret: UserConfig[:mastodon_instances][domain][:client_secret],
            retrieve: UserConfig[:mastodon_instances][domain][:retrieve],
          )
        end
      end

      def remove(domain)
        remove_datasources(domain)
        UserConfig[:mastodon_instances].delete(domain)
      end

      def domains
        UserConfig[:mastodon_instances].keys.dup
      end

      def settings
        UserConfig[:mastodon_instances].map do |domain, value|
          { domain: domain, retrieve: value[:retrieve] }
        end
      end
    end # class instance

    def store
      configs = UserConfig[:mastodon_instances].dup
      configs[domain] = { client_key: client_key, client_secret: client_secret, retrieve: retrieve }
      UserConfig[:mastodon_instances] = configs
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

    def inspect
      "mastodon-instance(#{domain})"
    end

  end
end
