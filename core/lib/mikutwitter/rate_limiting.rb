# -*- coding: utf-8 -*-

require "mikutwitter/basic"
require "mikutwitter/utils"

# API残数
module MikuTwitter::RateLimiting

  # 規制されていたらtrue
  def rate_limiting?
    limit, remain, reset = api_remain
    remain and reset and remain <= 0 and Time.new <= reset end

  # APIリクエスト制限の残数を返す(OAuthトークン毎)
  # _response_ にHTTPRequestを設定すると、その数が設定される
  def api_remain(response = nil)
    if response and response['X-RateLimit-Reset']
      time = Time.at(response['X-RateLimit-Reset'].to_i)
      if (!defined?(@api_remain[2])) or time !=  @api_remain[2]
        notice "event reserved :before_exit_api_section at #{time}"
        Reserver.new(time - 60){ Plugin.call(:before_exit_api_section) } rescue nil end
      @api_remain = [ response['X-RateLimit-Limit'].to_i,
                      response['X-RateLimit-Remaining'].to_i,
                      time ]
    end
    return *@api_remain end

  # APIリクエスト制限の残数を返す(IPアドレス毎)
  # _response_ にHTTPRequestを設定すると、その数が設定される
  def ip_api_remain(response = nil)
    if response and response['X-RateLimit-Reset'] then
      @ip_api_remain = [ response['X-RateLimit-Limit'].to_i,
                      response['X-RateLimit-Remaining'].to_i,
                      Time.at(response['X-RateLimit-Reset'].to_i) ] end
    return *@ip_api_remain end


  # OAuth APIが切れたイベントを発生させる
  def fire_oauth_limit_event
    @last_oauth_limit ||= nil
    limit, remain, reset = api_remain
    if(@last_oauth_limit != reset)
      Plugin.call(:apilimit, reset)
      @last_oauth_limit = reset end
  end

end

class MikuTwitter; include MikuTwitter::RateLimiting end
