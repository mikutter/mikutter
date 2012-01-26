# -*- coding: utf-8 -*-

module OAuth

  class AccessToken < ConsumerToken
    def get_request(http_method, path, *arguments)
      request_uri = URI.parse(path)
      site_uri = consumer.uri
      is_service_uri_different = (request_uri.absolute? && request_uri != site_uri)
      consumer.uri(request_uri) if is_service_uri_different
      response = super(http_method, path, *arguments)
      # NOTE: reset for wholesomeness? meaning that we admit only AccessToken service calls may use different URIs?
      # so reset in case consumer is still used for other token-management tasks subsequently?
      # consumer.uri(site_uri) if is_service_uri_different
      response
    end
  end

  class ConsumerToken < Token
    def get_request(http_method, path, *arguments)
      consumer.get_request(http_method, path, self, {}, *arguments)
    end
  end

  class Consumer
    def get_request(http_method, path, token = nil, request_options = {}, *arguments)
      if path !~ /^\//
        @http = create_http(path)
        _uri = URI.parse(path)
        path = "#{_uri.path}#{_uri.query ? "?#{_uri.query}" : ""}" end
      create_signed_request(http_method, path, token, request_options, *arguments) end

    alias request_ADzX5f8 request

    # 通信中に例外が発生した場合、コネクションを強制的に切断する
    def request(http_method, path, *arguments, &block)
      request_ADzX5f8(http_method, path, *arguments, &block)
    rescue Exception => e
      @http.finish if defined? @http and @http.started?
      raise e end
  end

end
