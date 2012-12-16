# -*- coding: utf-8 -*-

require "mikutwitter/basic"
require "mikutwitter/utils"

# API残数
module MikuTwitter::RateLimiting

  # APIのリソース。
  # Resource = Struct.new(:limit, :remain, :reset, :endpoint)
  class Resource
    attr_reader :limit, :remain, :reset, :endpoint
    def initialize(limit, remain, reset, endpoint)
      type_strict [[limit, Numeric], [remain, Numeric], [reset, Time], [endpoint, :to_s]]
      @limit, @remain, @reset, @endpoint = limit, remain, reset.freeze, endpoint.to_s.freeze
    end

    alias [] __send__

    # 規制されているなら真
    def limit?
      remain and reset and remain <= 0 and Time.new <= reset end end

  def initialize(*args)
    super
    @api_remain = {}            # resource_name => Resource
  end

  def ratelimit(resource_name)
    type_strict resource_name => String
    @api_remain[resource_name] end

  # APIリクエスト制限の残数を返す(OAuthトークン毎)
  # _response_ にHTTPRequestを設定すると、その数が設定される
  def ratelimit_rewind(resource_name, response = nil)
    type_strict resource_name => :to_s
    resource_name = resource_name.to_s.freeze
    if response and response['X-Rate-Limit-Reset']
      time = Time.at(response['X-Rate-Limit-Reset'].to_i)
      if (!defined?(@api_remain[2])) or time !=  @api_remain[2]
        notice "event reserved :before_exit_api_section at #{time}"
        Reserver.new(time - 60){ Plugin.call(:before_exit_api_section) } rescue nil end
      @api_remain[resource_name] = Resource.new(response['X-Rate-Limit-Limit'].to_i,
                                                response['X-Rate-Limit-Remaining'].to_i,
                                                time,
                                                resource_name) end
    @api_remain[resource_name] end

end

class MikuTwitter; include MikuTwitter::RateLimiting end
