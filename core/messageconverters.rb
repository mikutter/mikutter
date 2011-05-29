# -*- coding: utf-8 -*-
require 'uri'

=begin rdoc
  URL短縮・展開のためのクラス。これを継承したクラスを作れば短縮URL機能として利用されるようになる
=end
class MessageConverters
  def self.regist
    converter = self.new
    plugin = Plugin.create(converter.plugin_name)
    [:shrink, :expand].each{ |convert|
      plugin.add_event_filter("#{convert}_url"){ |url, &cont|
        converted = converter.__send__("#{convert}_url", url)
        if(converted)
          cont.call([converted])
        else
          [url] end } }
    plugin.add_event_filter(:is_expanded){ |url, &cont|
      if(converter.shrinked_url?(url))
        cont.call([false])
      else
        [url] end }
  end

  # textからURLを抜き出してすべて短縮したテキストを返す
  def self.shrink_url_all(text)
    urls = text.matches(shrinkable_url_regexp)
    return text if(urls.empty?)
    table = self.shrink_url(urls)
    text.gsub(shrinkable_url_regexp){ |k| table[k] } if table end

  # textからURLを抜き出してすべて展開したテキストを返す
  def self.expand_url_all(text)
    urls = text.matches(shrinkable_url_regexp)
    return text if(urls.empty?)
    table = self.expand_url(urls)
    text.gsub(shrinkable_url_regexp){ |k| table[k] } if table end

  # URL _url_ を短縮する。urlは配列で渡す。
  # { 渡されたURL => 短縮後URL }の配列を返す
  def self.shrink_url(urls)
    result = Hash.new
    urls.each{ |url|
      url.freeze
      if shrinked_url?(url)
        result[url] = url
      else
        result[url] = Plugin.filtering(:shrink_url, url).first end }
    result.freeze end

  # URL _url_ を展開する。urlは配列で渡す。
  # { 渡されたURL => 展開後URL }の配列を返す

  def self.expand_url(urls)
    result = Hash.new
    urls.each{ |url|
      url.freeze
      if shrinked_url?(url)
        result[url] = Plugin.filtering(:expand_url, url).first
      else
        result[url] = url end }
    result.freeze end

  def self.shrinkable_url_regexp
    URI.regexp(['http','https']) end

  def self.shrinked_url?(url)
    not Plugin.filtering(:is_expanded, url).first
  end

  def shrink_url(url)
    nil end

  def expand_url(url)
    nil end

  def shrinked_url?(url)
    raise end

  def plugin_name
    raise end

  # no override follow

  def shrink_url_ifnecessary(url)
    if shrinked_url?(url)
      url
    else
      shrink_url(url)
    end
  end
end
