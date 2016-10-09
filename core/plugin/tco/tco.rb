# -*- coding: utf-8 -*-
# エンティティで展開しきれなかった t.co で短縮されたURLを展開する。
# http://www.gistlog.org/gist/1008272

require 'uri'
require 'net/http'

module Plugin::TCo
  SHRINKED_MATCHER = /\Ahttps?:\/\/t\.co\//.freeze

  extend self

  def expand_url(url)
    no_mainthread
    begin
      res = Timeout.timeout(5){ Net::HTTP.get_response(URI.parse(url)) }
      if res.is_a?(Net::HTTPRedirection)
        res["location"]
      else
        url end
    rescue Exception => e
      warn e
      url end end
end

Plugin.create :tco do
  on_gui_timeline_add_messages do |i_timeline, messages|
    messages.map(&:entity).each do |entity|
      entity.select{|_|
        :urls == _[:slug] and Plugin::TCo::SHRINKED_MATCHER =~ _[:url]
      }.each do |link|
        SerialThread.new do
          notice "detect tco shrinked url: #{link[:url]} by #{entity.message}"
          expanded = Plugin::TCo.expand_url(link[:url])
          entity.add link.merge(url: expanded, face: expanded) end
      end end end

  filter_expand_url do |urlset|
    divided = urlset.group_by{|url| !!(Plugin::TCo::SHRINKED_MATCHER =~ url) }
    divided[false] ||= []
    divided[true] ||= []
    [divided[false] + divided[true].map(&Plugin::TCo.method(:expand_url))] end
end
