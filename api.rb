require 'net/http'
require 'json'
require 'uri'

module Plugin::Worldon
  class API
    class << self
      def call(method, domain, path, access_token = nil, **opts)
        #pp opts
        url = 'https://' + domain + path
        url = Diva::URI.new(url)
        case method
        when :get
          if !opts.empty?
            path = url.path + '?' + URI.encode_www_form(opts)
          end
          req = Net::HTTP::Get.new(path)
        when :post
          req = Net::HTTP::Post.new(url.path)
          req.set_form_data(opts)
        end

        if !access_token.nil? && access_token.length > 0
          req["Authorization"] = "Bearer " + access_token
        end

        #pp req

        http = Net::HTTP.new(url.host, url.port)
        #http.set_debug_output $stderr
        if url.scheme == 'https'
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
          error resp.body
        end
      end
    end
  end
end
