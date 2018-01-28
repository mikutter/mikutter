require 'net/http'
require 'json'
require 'uri'

module Plugin::Worldon
  class API
    class << self
      def call(method, domain, path, access_token = nil, **opts)
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
        end

        resp = http.start do |http|
          http.request(req)
        end
        #pp resp

        case resp
        when Net::HTTPSuccess
          JSON.parse(resp.body, symbolize_names: true)
        else
          error "API.call did'nt return Net::HTTPSuccess"
          pp req.path
          pp resp
          {}
        end
      end

      def status(domain, id)
        call(:get, domain, '/api/v1/statuses/' + id.to_s)
      end

      def status_by_url(domain, access_token, url)
        resp = call(:get, domain, '/api/v1/search', access_token, q: url.to_s, resolve: true)
        resp.statuses
      end

      def get_local_status_id(world, status)
        remote_status = Plugin::Worldon::API.status(world.domain, status.id)
        if remote_status[:uri] == status.uri
          status.id
        else
          # 別インスタンス起源のstatusだったので検索する
          statuses = Plugin::Worldon::API.status_by_url(status.url)
          statuses[0][:id].to_i
        end
      end
    end
  end
end
