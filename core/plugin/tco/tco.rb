# -*- coding: utf-8 -*-
# エンティティで展開しきれなかった t.co で短縮されたURLを展開する。
# http://www.gistlog.org/gist/1008272

require 'uri'
require 'net/http'

class TCo < MessageConverters

  def plugin_name()
    :tco
  end

  def shrink_url(url)
    # 未対応
    return url
  end

  def shrinked_url?(url)
    !!(url =~ /http:\/\/t\.co\//)
  end

  def expand_url(url)
    type_strict url => :to_s
    hash = Hash.new
    begin
      res = timeout(5){ Net::HTTP.get_response(URI.parse(url.to_s)) }
      if res.is_a?(Net::HTTPRedirection)
        res["location"]
      else
        url.to_s end
    rescue Exception => e
      warn e
      url.to_s
    end
  end

  regist
end
