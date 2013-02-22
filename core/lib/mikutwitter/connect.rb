# -*- coding: utf-8 -*-

require "mikutwitter/basic"
require "mikutwitter/utils"
require "mikutwitter/authentication_failed_action"
require "mikutwitter/rate_limiting"
require "oauth"

# OAuth関連
module MikuTwitter::Connect

  INVALID_REQUEST = 32
  PAGE_DOES_NOT_EXIST = 34
  BASIC_AUTHENTICATION_IS_NOT_SUPPORTED = 53
  RATE_LIMIT_EXCEEDED = 88
  INVALID_OR_EXPIRED_TOKEN = 89
  OVER_CAPACITY = 130
  INTERNAL_ERROR = 131
  TIMESTAMP_TOOLATE = 135
  BAD_AUTHENTICATION_DATA = 215

  attr_accessor :consumer_key, :consumer_secret, :a_token, :a_secret, :oauth_url

  def initialize(*a, &b)
    @oauth_url = 'https://twitter.com'
    super(*a, &b)
  end

  def consumer(url=oauth_url)
    OAuth::Consumer.new(consumer_key, consumer_secret,
                        :site => url) end

  def access_token(url=@oauth_url)
    OAuth::AccessToken.new(consumer(url), a_token, a_secret) end

  def request_oauth_token
    consumer.get_request_token end

  # OAuth経由でurlを叩く
  # ==== Args
  # [method] メソッド。:get, :post, :put, :delete の何れか
  # [url] 叩くURL
  # [options]
  #   API引数。ただし、以下のキーは特別扱いされ、API引数からは除外される
  #   :head :: HTTPリクエストヘッダ（Hash）
  # ==== Return
  # 戻り値(HTTPResponse)
  # ==== Exceptions
  # TimeoutError
  def query_with_oauth!(method, url, options = {})
    if [:get, :delete].include? method
      path = url + get_args(options)
      res = access_token.__send__(method, path, options[:head])
    else
      path = url
      query_args = options.melt
      head = options[:head]
      query_args.delete(:head)
      res = access_token.__send__(method, path, query_args, head) end
    if res.is_a? Net::HTTPResponse
      case res.code
      when '200'
      when '401'
        notice "#{res.code} Authorization failed."
        notice res.body
        notice "trigger request: #{path}"
        begin
          errors = (JSON.parse(res.body)["errors"] rescue nil)
          errors.each { |error|
            notice error
            if [INVALID_OR_EXPIRED_TOKEN].include? error["code"]
              atoken = authentication_failed_action(method, url, options, res)
              notice atoken
              return query_with_oauth!(method, url, options) if atoken end }
        rescue Exception => e
          notice e end
      when '429'
        raise MikuTwitter::RateLimitError.new("Rate limit #{url}", nil)
      end
    end
    res
  end

end

class MikuTwitter; include MikuTwitter::Connect end


