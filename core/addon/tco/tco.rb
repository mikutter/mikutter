# -*- coding: utf-8 -*-
# エンティティで展開しきれなかった t.co で短縮されたURLを展開する。
# http://www.gistlog.org/gist/1008272

miquire :core, 'messageconverters'
miquire :addon, 'addon'

class TCo < MessageConverters
  require 'uri'
  require 'net/http'
  def plugin_name()
    :tco
  end
  def shrink_url(url)
    # 未対応
    return url
  end
  def shrinked_url?(url)
    if url =~ /http:\/\/t\.co\// then
      return true
    else
      return false
    end
  end
  def expand_url(url)
    hash = Hash.new
    res = Net::HTTP.get_response(URI.parse(url))
    if res.is_a?(Net::HTTPRedirection)
      return res["location"]
    else
      return url
    end
  end
  regist
end
