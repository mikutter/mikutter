# -*- coding: utf-8 -*-

require "mikutwitter/basic"
require "mikutwitter/utils"
require "mikutwitter/rate_limiting"

# ログインせずにAPIを実行する機能
module MikuTwitter::Unauthorized

  attr_accessor :open_timeout, :read_timeout

  include MikuTwitter::Utils

  def initialize(*a, &b)
    @open_timeout = @read_timeout = 10
    super(*a, &b) end

  # urlを叩く
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
  def query_without_oauth!(method, url, options = {})
    uri = URI.parse(url)
    http = connection(options[:host] || twitter_host)
    http.start
    res = http.__send__(method, uri.path + get_args(options), options[:head] || {})
    if res.is_a? Net::HTTPResponse
      limit, remain, reset = ip_api_remain(res)
      Plugin.call(:ipapiremain, remain, reset) end
    res
  end

  private

  def connection(host = twitter_host)
    http = Net::HTTP.new(host)
    http.open_timeout, http.read_timeout = @open_timeout, @read_timeout
    http
  end

end

class MikuTwitter; include MikuTwitter::Unauthorized end
