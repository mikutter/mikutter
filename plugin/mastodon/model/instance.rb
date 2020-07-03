module Plugin::Mastodon
  class Instance < Diva::Model
    register :mastodon_instance, name: Plugin[:mastodon]._('Mastodonサーバー')

    field.string :domain, required: true
    field.string :client_key, required: true
    field.string :client_secret, required: true
    field.bool :retrieve, required: true

    class << self
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
        if UserConfig[:mastodon_instances][domain]
          self.new(
            domain: domain,
            client_key: UserConfig[:mastodon_instances][domain][:client_key],
            client_secret: UserConfig[:mastodon_instances][domain][:client_secret],
            retrieve: UserConfig[:mastodon_instances][domain][:retrieve],
          )
        end
      end

      def remove(domain)
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

    def initialize(*)
      super
      Plugin.call(:mastodon_server_created, self)
    end

    def sse
      Plugin::Mastodon::SSEPublicType.new(server: self)
    end

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

    def ==(other)
      case other
      when Plugin::Mastodon::Instance
        domain == other.domain
      end
    end

    def inspect
      "#<#{self.class.name}: #{domain}>"
    end
  end
end
