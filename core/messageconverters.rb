# -*- coding: utf-8 -*-

require 'uri'
require 'timeout'

=begin rdoc
  URL短縮・展開のためのクラス。これを継承したクラスを作れば短縮URL機能として利用されるようになる
=end
class MessageConverters

  class << self
    ExpandExpire = Class.new(TimeoutError)

    attr_hash_accessor :expand_by_cache, :shrink_by_cache

    # _shrinked_ を展開したら _expanded_ になるということをキャッシュに登録する。
    # _shrinked_ を返す。
    def cache(shrinked, expanded)
      expand_by_cache[shrinked] = expanded.freeze
      shrink_by_cache[expanded] = shrinked.freeze end

    # サブクラスから呼び出す。そのクラスをURLの短縮/展開のためのクラスとして登録する。
    def regist
      converter = self.new
      plugin = Plugin.create(converter.plugin_name)
      [:shrink, :expand].each{ |convert|
        plugin.add_event_filter("#{convert}_url"){ |url, &cont|
          lock(url) do
            cached = if convert == :shrink then shrink_by_cache[url] else expand_by_cache[url] end
            cont.call([cached]) if cached
            converted = converter.__send__("#{convert}_url", url)
            if(converted)
              if convert == :shrink
                cache(converted, url)
              else
                cache(url, converted) end
              cont.call([converted])
            else
              [url] end end } }
      plugin.add_event_filter(:is_expanded){ |url, &cont|
        if(converter.shrinked_url?(url))
          cont.call([false])
        else
          [url] end }
    end

    # URLごとのロックを管理しているHashを取得し、ブロックの引数に渡して実行する。
    # ブロック内では、他のプロセスがそのHashを変更しないようにロックされている。
    def mutexes
      (@global_mutex ||= Mutex.new).synchronize {
        yield(@mutexes ||= TimeLimitedStorage.new(String, Mutex, 60)) } end

    # _url_ に対するMutexを作成・ロックして、ブロックを実行する。
    # ただし、urlが既にキャッシュにある場合は、Mutexは作成・ロックされず、単にブロックが実行される。
    def lock(url, &proc)
      mutex = mutexes{ |mutexes|
        mutexes[url] ||= Mutex.new if !(expand_by_cache.has_key?(url) || shrink_by_cache.has_key?(url)) }
      if mutex
        mutex.synchronize(&proc)
      else
        yield end end

    # textからURLを抜き出してすべて短縮したテキストを返す
    def shrink_url_all(text)
      urls = text.matches(shrinkable_url_regexp)
      return text if(urls.empty?)
      table = self.shrink_url(urls)
      text.gsub(shrinkable_url_regexp){ |k| table[k] } if table end

    # textからURLを抜き出してすべて展開したテキストを返す
    def expand_url_all(text)
      urls = text.matches(shrinkable_url_regexp)
      return text if(urls.empty?)
      table = self.expand_url(urls)
      text.gsub(shrinkable_url_regexp){ |k| table[k] } if table end

    # URL _url_ を短縮する。urlは配列で渡す。
    # { 渡されたURL => 短縮後URL }の配列を返す
    def shrink_url(urls)
      result = Hash.new
      urls.each{ |url|
        url.freeze
        if shrinked_url?(url)
          result[url] = url
        else
          if(shrink_by_cache[url])
            result[url] = shrink_by_cache[url]
          else
            result[url] = Plugin.filtering(:shrink_url, url).first
            cache(result[url], url) if result[url] end end }
      result.freeze end

    # URL _url_ を展開する。urlは配列で渡す。
    # { 渡されたURL => 展開後URL }の配列を返す
    def expand_url(urls)
      result = Hash.new
      urls.each{ |url|
        result[url] = expand_url_one(url) }
      result.freeze end

    # urlを一つだけ受け取り、再帰的に展開する。
    # ただし再帰的展開は4段までしか行わず、展開系が渡されたURLと同じになるか
    # それ以上展開できなくなれば直ちにそれを返す。
    def expand_url_one(url, recur=0)
      return expand_by_cache[url] if expand_by_cache[url]
      lock(url) do
        if recur < 4 and shrinked_url?(url)
          expanded = timeout(5, ExpandExpire){ Plugin.filtering(:expand_url, url).first.freeze }
          if(expanded == url)
            url
          else
            result = expand_url_one(expanded, recur + 1)
            cache(url, result)
            result end
        else
          url end end
    rescue ExpandExpire => e
      notice "url expand failed: timeout #{url}"
      cache(url, url)
      url end

    def shrinkable_url_regexp
      URI.regexp(['http','https']) end

    def shrinked_url?(url)
      not Plugin.filtering(:is_expanded, url).first
    end

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
