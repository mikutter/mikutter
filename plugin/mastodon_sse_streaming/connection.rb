# frozen_string_literal: true

module Plugin::MastodonSseStreaming
  class Connection
    attr_reader :method
    attr_reader :uri
    attr_reader :headers
    attr_reader :params           # TODO: paramsとoptsは名前何とかする
    attr_reader :opts
    attr_reader :thread

    def initialize(method:, uri:, headers:, params:, opts:, thread:)
      @method = method
      @uri = uri
      @headers = headers
      @params = params
      @opts = opts
      @thread = thread
    end
  end
end
