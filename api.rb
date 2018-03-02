require 'httpclient'
require 'json'

module Plugin::Worldon
  class API
    class << self
      def call(method, domain, path = nil, access_token = nil, file_keys = [], **params)
        begin
          if domain.is_a? Diva::URI
            uri = domain
            domain = uri.host
            path = uri.path
          else
            url = 'https://' + domain + path
            uri = Diva::URI.new(url)
          end

          headers = []
          if access_token && !access_token.empty?
            headers << ["Authorization", "Bearer " + access_token]
          end

          conv = []
          begin
            files = []
            file_keys.each do |key|
              f = File.open(params[key], 'rb')
              files << f
              params[key] = f
            end
            params.each do |key, val|
              if val.is_a? Array
                val.each do |v|
                  conv << [key.to_s + '[]', v]
                end
              else
                conv << [key.to_s, val]
              end
            end
            pp conv

            query = {}
            body = {}

            case method
            when :get
              query = conv
            when :post
              body = conv
            end

            notice "Worldon::API.call #{method.to_s} #{uri} #{params.to_s}"

            client = HTTPClient.new
            resp = client.request(method, uri.to_s, query, body, headers)
          ensure
            files.each do |f|
              f.close
            end
          end

          case resp.status
          when 200
            hash = JSON.parse(resp.content, symbolize_names: true)
            parse_Link(resp, hash)
          else
            warn "API.call did'nt return 200 Success"
            pp [uri.to_s, params, resp]
            $stdout.flush
            nil
          end
        rescue => e
          error "API.call raise exception"
          pp e
          $stdout.flush
          nil
        end
      end

      def parse_Link(resp, hash)
        link = resp.header['Link'].first
        return hash if ((!hash.is_a? Array) || link.nil?)
        hash = { array: hash, __Link__: {} }
        link
          .split(', ')
          .each do |line|
            /^<(.*)>; rel="(.*)"$/.match(line) do |m|
              hash[:__Link__][$2.to_sym] = Diva::URI.new($1)
            end
          end
        hash
      end

      def status(domain, id)
        call(:get, domain, '/api/v1/statuses/' + id.to_s)
      end

      def status_by_url(domain, access_token, url)
        resp = call(:get, domain, '/api/v1/search', access_token, q: url.to_s, resolve: true)
        return nil if resp.nil?
        resp[:statuses]
      end

      def get_local_status_id(world, status)
        return status.id if world.domain == status.domain

        # 別インスタンス起源のstatusなので検索する
        statuses = status_by_url(world.domain, world.access_token, status.url)
        if statuses.nil? || statuses[0].nil? || statuses[0][:id].nil?
          nil
        else
          statuses[0][:id]
        end
      end
    end
  end
end
