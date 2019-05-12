require 'httpclient'
require 'json'
require 'stringio'

module Plugin::Mastodon
  class APIResult
    attr_reader :value
    attr_reader :header

    def initialize(value, header = nil)
      @value = value
      @header = header
    end

    def [](idx)
      @value[idx]
    end

    def []=(idx, val)
      @value[idx] = val
    end

    def to_h
      @value.to_h
    end

    def to_a
      @value.to_a
    end
  end

  class API
    ExceptionResponse = Struct.new(:body) do
      def code
        0
      end
    end

    class << self
      def build_query_recurse(params, results = [], files = [], prefix = '', to_multipart = false)
        if params.is_a? Hash
          # key-value pairs
          params.each do |key, val|
            inner_prefix = "#{prefix}[#{key.to_s}]"
            results, files, to_multipart = build_query_recurse(val, results, files, inner_prefix, to_multipart)
          end
        elsif params.is_a? Array
          params.each_index do |i|
            inner_prefix = "#{prefix}[#{i}]"
            results, files, to_multipart = build_query_recurse(params[i], results, files, inner_prefix, to_multipart)
          end
        elsif params.is_a? Set
          results, files, to_multipart = build_query_recurse(params.to_a, results, files, prefix, to_multipart)
        else
          key = "#{prefix}".sub('[', '').sub(']', '')
          /^(.*)\[\d+\]$/.match(key) do |m|
            key = "#{m[1]}[]"
          end
          value = params
          if value.is_a?(Pathname) || value.is_a?(Plugin::Photo::Photo)
            to_multipart = true
          end

          case value
          when Pathname
            # multipart/form-data にするが、POSTリクエストではない可能性がある（PATCH等）ため、ある程度自力でつくる。
            # boundary作成や実際のbody構築はhttpclientに任せる。
            filename = value.basename.to_s
            disposition = "form-data; name=\"#{key}\"; filename=\"#{filename}\""
            f = File.open(value.to_s, 'rb')
            files << f
            results << {
              "Content-Type" => "application/octet-stream",
              "Content-Disposition" => disposition,
              :content => f,
            }
          when Plugin::Photo::Photo
            filename = Pathname(value.perma_link.path).basename.to_s
            disposition = "form-data; name=\"#{key}\"; filename=\"#{filename}\""
            results << {
              "Content-Type" => "application/octet-stream",
              "Content-Disposition" => "form-data; name=\"#{key}\"; filename=\"#{filename}\"",
              :content => StringIO.new(value.blob, 'r'),
            }
          else
            if to_multipart
              results << {
                "Content-Type" => "application/octet-stream",
                "Content-Disposition" => "form-data; name=\"#{key}\"",
                :content => value,
              }
            else
              results << [key, value]
            end
          end
        end
        [results, files, to_multipart]
      end

      # httpclient向けにパラメータHashを変換する
      def build_query(params, headers)
        results, files, to_multipart = build_query_recurse(params)
        if to_multipart
          headers << ["Content-Type", "multipart/form-data"]
        end
        [results, headers, files]
      end

      # APIアクセスを行うhttpclientのラッパメソッド
      def call(method, domain, path = nil, access_token = nil, opts = {}, headers = [], **params)
        Thread.new do
          call!(method, domain, path, access_token, opts, headers, **params)
        end
      end

      def call!(method, domain, path = nil, access_token = nil, opts = {}, headers = [], **params)
        uri = domain_path_to_uri(domain, path)
        resp = raw_response!(method, uri, access_token, headers, **params)
        case resp&.status
        when 200
          parse_link(resp, JSON.parse(resp.content, symbolize_names: true))
        else
          warn "API.call did'nt return 200 Success"
          Plugin.activity(:system, "APIアクセス失敗", description: "URI: #{uri}\nparameters: #{params}\nHTTP status: #{resp.status}\nresponse:\n#{resp.body}") rescue nil
          nil
        end
      end

      def raw_response!(method, uri, access_token, headers, **params)
        if access_token && !access_token.empty?
          headers += [["Authorization", "Bearer " + access_token]]
        end
        query_timer(method, uri, params, headers) do
          send_request(method, params, headers, uri)
        end
      end

      private def domain_path_to_uri(domain, path)
        if domain.is_a? Diva::URI
          domain
        else
          Diva::URI.new('https://' + domain + path)
        end
      end

      private def query_timer(method, uri, params, headers, &block)
        start_time = Time.new.freeze
        serial = uri.to_s.hash ^ params.freeze.hash
        Plugin.call(:query_start,
                    serial:     serial,
                    method:     method,
                    path:       uri,
                    options:    params,
                    headers:    headers,
                    start_time: start_time)
        result = block.call
        Plugin.call(:query_end,
                    serial:     serial,
                    method:     method,
                    path:       uri,
                    options:    params,
                    start_time: start_time,
                    end_time:   Time.new.freeze,
                    res:        result)
        result
      rescue => exc
        Plugin.call(:query_end,
                    serial:     serial,
                    method:     method,
                    path:       uri,
                    options:    params,
                    start_time: start_time,
                    end_time:   Time.new.freeze,
                    res:        ExceptionResponse.new("#{exc.message}\n" + exc.backtrace.join("\n")))
        raise
      end

      private def send_request(method, params, headers, uri)
        query, headers, files = build_query(params, headers)
        body = nil
        if method != :get  # :post, :patch
          body = query
          query = nil
        end
        notice "Mastodon::API.call #{method.to_s} #{uri} #{headers.to_s} #{query.to_s} #{body.to_s}"
        HTTPClient.new.request(method, uri.to_s, query, body, headers)
      ensure
        files&.each(&:close)
      end

      def parse_link(resp, hash)
        link = resp.header['Link'].first
        return APIResult.new(hash) if ((!hash.is_a? Array) || link.nil?)
        header =
          link
            .split(', ')
            .map do |line|
          /^<(.*)>; rel="(.*)"$/.match(line) do |m|
            [$2.to_sym, Diva::URI.new($1)]
          end
        end
            .to_h
        APIResult.new(hash, header)
      end

      def status(domain, id)
        call(:get, domain, '/api/v1/statuses/' + id.to_s)
      end

      def status!(domain, id)
        call!(:get, domain, '/api/v1/statuses/' + id.to_s)
      end

      def status_by_url(domain, access_token, url)
        call(:get, domain, '/api/v1/search', access_token, q: url.to_s, resolve: true).next{ |resp|
          resp[:statuses]
        }
      end

      def status_by_url!(domain, access_token, url)
        call!(:get, domain, '/api/v1/search', access_token, q: url.to_s, resolve: true).next{ |resp|
          resp[:statuses]
        }
      end

      def account_by_url(domain, access_token, url)
        call(:get, domain, '/api/v1/search', access_token, q: url.to_s, resolve: true).next{ |resp|
          resp[:accounts]
        }
      end

      # _world_ における、 _status_ のIDを検索して返す。
      # _status_ が _world_ の所属するのと同じサーバに投稿されたものなら、 _status_ のID。
      # 異なるサーバの _status_ なら、 _world_ のサーバに問い合わせて、そのIDを返すDeferredをリクエストする。
      # ==== Args
      # [world] World Model
      # [status] トゥート
      # ==== Return
      # [Delayer::Deferred] _status_ のローカルにおけるID
      def get_local_status_id(world, status)
        if world.domain == status.domain
          Delayer::Deferred.new{ status.id }
        else
          status_by_url(world.domain, world.access_token, status.url).next{ |statuses|
            statuses.dig(0, :id).tap do |id|
              raise 'Status id does not found.' unless id
            end
          }
        end
      end

      # _world_ における、 _account_ のIDを検索して返す。
      # _account_ が _world_ の所属するのと同じサーバに投稿されたものなら、 _account_ のID。
      # 異なるサーバの _account_ なら、 _world_ のサーバに問い合わせて、そのIDを返すDeferredをリクエストする。
      # ==== Args
      # [world] World Model
      # [account] アカウント (Plugin::Mastodon::Account)
      # ==== Return
      # [Delayer::Deferred] _account_ のローカルにおけるID
      def get_local_account_id(world, account)
        if world.domain == account.domain
          Delayer::Deferred.new{ account.id }
        else
          account_by_url(world.domain, world.access_token, account.url).next{ |accounts|
            accounts&.dig(0, :id)
          }
        end
      end

      # Link headerがあるAPIを連続的に叩いて1要素ずつyieldする
      # ==== Args
      # [method] HTTPメソッド
      # [domain] 対象ドメイン
      # [path] APIパス
      # [access_token] トークン
      # [opts] オプション
      #   [:direction] :next or :prev
      #   [:wait] APIコール間にsleepで待機する秒数
      # [headers] 追加ヘッダ
      # [params] GET/POSTパラメータ
      def all!(method, domain, path = nil, access_token = nil, opts = {}, headers = [], **params)
        opts[:direction] ||= :next
        opts[:wait] ||= 1

        while true
          list = API.call!(method, domain, path, access_token, opts, headers, **params)

          if list && list.value.is_a?(Array)
            list.value.each { |hash| yield hash }
          end

          break unless list.header.has_key?(opts[:direction])

          url = list.header[opts[:direction]]
          params = URI.decode_www_form(url.query).to_h.symbolize

          sleep opts[:wait]
        end
      end

      def all_with_world!(world, method, path = nil, opts = {}, headers = [], **params, &block)
        all(method, world.domain, path, world.access_token, opts, headers, **params, &block)
      end

    end
  end

end
