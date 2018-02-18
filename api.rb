require 'net/http'
require 'json'
require 'uri'
require 'openssl'

module Plugin::Worldon
  class API
    class << self
      def call(method, domain, path, access_token = nil, **opts)
        begin
          url = 'https://' + domain + path
          uri = Diva::URI.new(url)
          case method
          when :get
            path = uri.path
            if !opts.empty?
              path += '?' + URI.encode_www_form(opts)
            end
            req = Net::HTTP::Get.new(path)
          when :post
            req = Net::HTTP::Post.new(uri.path)
            req.set_form_data(opts)
          end

          if !access_token.nil? && access_token.length > 0
            req["Authorization"] = "Bearer " + access_token
          end

          notice "Worldon::API.call #{method.to_s} #{domain} #{req.path}"

          http = Net::HTTP.new(uri.host, uri.port)
          #http.set_debug_output $stderr
          if uri.scheme == 'https'
            http.use_ssl = true
            http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          end

          resp = http.start do |http|
            http.request(req)
          end

          case resp
          when Net::HTTPSuccess
            hash = JSON.parse(resp.body, symbolize_names: true)
            parse_Link(resp, hash)
          else
            warn "API.call did'nt return Net::HTTPSuccess"
            pp req.path
            pp resp
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
        link = resp['Link']
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
        statuses = Plugin::Worldon::API.status_by_url(world.domain, world.access_token, status.url)
        if statuses.nil? || statuses[0].nil? || statuses[0][:id].nil?
          nil
        else
          statuses[0][:id].to_i
        end
      end
    end
  end
end
