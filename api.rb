require 'net/http'
require 'json'
require 'uri'
require 'openssl'

require "stringio"

module Plugin::Worldon
  # MultiPartFormDataStreamクラス
  # https://qiita.com/asukamirai/items/c950c65c6473ca8ca96c を元に一部改変
  class MultiPartFormDataStream
    def initialize(name, filename, file, boundary=nil)
      @boundary = boundary || "boundary"
      first = [boundary_line, part_header(name, filename)].join(new_line)
      last = ["", boundary_last, ""].join(new_line)
      @first = StringIO.new(first)
      @file = file
      @last = StringIO.new(last)
      @size = @first.size + @file.size + @last.size
    end

    def content_type
      "multipart/form-data; boundary=#{@boundary}"
    end

    def boundary_line
      "--#{@boundary}"
    end

    def boundary_last
      "--#{@boundary}--"
    end

    def part_header(name, filename)
      [
        "Content-Disposition: form-data; name=\"#{name}\"; filename=\"#{filename}\"",
        "Content-Type: application/octet-stream",
        "",
        ""
      ].join(new_line)
    end

    def new_line
      "\r\n"
    end

    def read(len=nil, buf=nil)
      return @first.read(len, buf) unless @first.eof?
      return @file.read(len, buf) unless @file.eof?
      return @last.read(len, buf)
    end

    def size
      @size
    end

    def eof?
      @last.eof?
    end
  end

  class API
    class << self
      def call(method, domain, path = nil, access_token = nil, filepath: nil, **opts)
        begin
          if domain.is_a? Diva::URI
            uri = domain
            domain = uri.host
            path = uri.path
          else
            url = 'https://' + domain + path
            uri = Diva::URI.new(url)
          end

          case method
          when :get
            path = uri.path
            if !opts.empty?
              path += '?' + URI.encode_www_form(opts)
            end
            req = Net::HTTP::Get.new(path)
          when :post
            req = Net::HTTP::Post.new(uri.path)
            if filepath.nil? && !opts.empty?
              params = []
              opts.each do |key, value|
                if value.is_a? Array
                  value.each do |v|
                    params << ["#{key.to_s}[]", v]
                  end
                else
                  params << [key.to_s, value]
                end
              end
              req.body = URI.encode_www_form(params)
            else
              # TODO: ファイルアップロードとパラメータ付与が同時にあるケース
            end
          end

          if access_token && !access_token.empty?
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
            fobj = nil
            begin
              if method === :post && filepath
                notice "Worldon::API.call uploading #{filepath.to_s}"

                fobj = File.open(filepath.to_s, "rb")
                form_data = MultiPartFormDataStream.new('file', filepath.basename.to_s, fobj)
                req.body_stream = form_data
                req["Content-Length"] = form_data.size
                req["Content-Type"] = form_data.content_type
              end

              http.request(req)
            ensure
              fobj.close if fobj
            end
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
          statuses[0][:id]
        end
      end
    end
  end
end
