require 'httpclient'
require 'json'
require 'stringio'

module Plugin::Worldon
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
    class << self
      # httpclient向けにパラメータHashを変換する
      def build_query(params, headers)
        # Hashで渡されるクエリパラメータをArray化する。
        # valueがArrayだった場合はkeyに[]を付加して平たくする。
        conv = []
        params.each do |key, val|
          if val.is_a? Array
            val.each do |v|
              elem_key = "#{key.to_s}[]"
              conv << [elem_key, v]
            end
          else
            conv << [key.to_s, val]
          end
        end
        params = conv

        # valueの種類に応じてhttpclientに渡すものを変える
        files = []
        to_multipart = params.any? {|key, value| value.is_a?(Pathname) || value.is_a?(Plugin::Photo::Photo) }

        if to_multipart
          headers << ["Content-Type", "multipart/form-data"]
        end

        params = params.map do |key, value|
          case value
          when Pathname
            # multipart/form-data にするが、POSTリクエストではない可能性がある（PATCH等）ため、ある程度自力でつくる。
            # boundary作成や実際のbody構築はhttpclientに任せる。
            filename = value.basename.to_s
            disposition = "form-data; name=\"#{key}\"; filename=\"#{filename}\""
            f = File.open(value.to_s, 'rb')
            files << f
            {
              "Content-Type" => "application/octet-stream",
              "Content-Disposition" => disposition,
              :content => f,
            }
          when Plugin::Photo::Photo
            filename = Pathname(value.perma_link.path).basename.to_s
            disposition = "form-data; name=\"#{key}\"; filename=\"#{filename}\""
            {
              "Content-Type" => "application/octet-stream",
              "Content-Disposition" => "form-data; name=\"#{key}\"; filename=\"#{filename}\"",
              :content => StringIO.new(value.blob, 'r'),
            }
          else
            if to_multipart
              {
                "Content-Type" => "application/octet-stream",
                "Content-Disposition" => "form-data; name=\"#{key}\"",
                :content => value,
              }
            else
              [key, value]
            end
          end
        end

        [params, headers, files]
      end

      # APIアクセスを行うhttpclientのラッパメソッド
      def call(method, domain, path = nil, access_token = nil, opts = {}, headers = [], **params)
        begin
          if domain.is_a? Diva::URI
            uri = domain
            domain = uri.host
            path = uri.path
          else
            url = 'https://' + domain + path
            uri = Diva::URI.new(url)
          end

          if access_token && !access_token.empty?
            headers += [["Authorization", "Bearer " + access_token]]
          end

          begin
            query, headers, files = build_query(params, headers)

            body = nil
            if method != :get  # :post, :patch
              body = query
              query = nil
            end

            notice "Worldon::API.call #{method.to_s} #{uri} #{headers.to_s} #{query.to_s} #{body.to_s}"

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

      def status_by_url(domain, access_token, url)
        resp = call(:get, domain, '/api/v1/search', access_token, q: url.to_s, resolve: true)
        return nil if resp.nil?
        resp[:statuses]
      end

      def account_by_url(domain, access_token, url)
        resp = call(:get, domain, '/api/v1/search', access_token, q: url.to_s, resolve: true)
        return nil if resp.nil?
        resp[:accounts]
      end

      def get_local_status_id(world, status)
        return status.id if world.domain == status.domain

        # 別サーバー起源のstatusなので検索する
        statuses = status_by_url(world.domain, world.access_token, status.url)
        if statuses.nil? || statuses[0].nil? || statuses[0][:id].nil?
          nil
        else
          statuses[0][:id]
        end
      end

      def get_local_account_id(world, account)
        return account.id if world.domain == account.domain

        # 別サーバー起源のaccountなので検索する
        accounts = account_by_url(world.domain, world.access_token, account.url)
        if accounts.nil? || accounts[0].nil? || accounts[0][:id].nil?
          nil
        else
          accounts[0][:id]
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
      def all(method, domain, path = nil, access_token = nil, opts = {}, headers = [], **params)
        opts[:direction] ||= :next
        opts[:wait] ||= 1

        while true
          list = API.call(method, domain, path, access_token, opts, headers, **params)

          if list && list.value.is_a?(Array)
            list.value.each { |hash| yield hash }
          end

          break unless list.header.has_key?(opts[:direction])

          url = list.header[opts[:direction]]
          params = URI.decode_www_form(url.query).to_h.symbolize

          sleep opts[:wait]
        end
      end

      def all_with_world(world, method, path = nil, opts = {}, headers = [], **params, &block)
        all(method, world.domain, path, world.access_token, opts, headers, **params, &block)
      end

    end
  end

end
