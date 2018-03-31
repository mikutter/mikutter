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

          begin
            conv = {}
            params.each do |key, val|
              if val.is_a? Array
                val.each_index do |i|
                  elem_key = "#{key.to_s}[#{i}]"
                  elem_val = val[i]
                  conv[elem_key] = elem_val
                end
              else
                conv[key.to_s] = val
              end
            end
            params = conv

            files = []
            conv = []
            if file_keys.size == 0
              params.each do |key, val|
                req_key = key.gsub(/\[[0-9]*\]/) { "[]" }
                conv << [req_key, val]
              end
            else
              # multipart/form-data にするが、POSTリクエストではない可能性がある（PATCH等）ため、ある程度自力でつくる。
              # boundary作成や実際のbody構築はhttpclientに任せる。
              headers << ["Content-Type", "multipart/form-data"]
              file_keys.each do |key|
                key = key.to_s
                filename = params[key]
                req_key = key.gsub(/\[[0-9]*\]/) { "[]" }
                req_filename = Pathname(filename).basename.to_s
                disposition = "form-data; name=\"#{req_key}\"; filename=\"#{req_filename}\""
                f = File.open(filename, 'rb')
                files << f
                conv << {
                  "Content-Type" => "application/octet-stream",
                  "Content-Disposition" => disposition,
                  :content => f,
                }
                params.delete(key)
              end
              params.each do |key, val|
                conv << {
                  "Content-Type" => "application/octet-stream",
                  "Content-Disposition" => "form-data; name=\"#{key}\"",
                  :content => val,
                }
              end
            end
            params = conv

            query = {}
            body = {}

            case method
            when :get
              query = params
            else # :post, :patch
              body = params
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
            pp [uri.to_s, query, body, headers, resp] if Mopt.error_level >= 2
            $stdout.flush
            nil
          end
        rescue => e
          error "API.call raise exception"
          pp e if Mopt.error_level >= 1
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
