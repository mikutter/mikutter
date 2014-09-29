# -*- coding: utf-8 -*-
require 'cgi'

module Plugin::Bitly
  USER = 'mikutter'.freeze
  APIKEY = 'R_70170ccac1099f3ae1818af3fa7bb311'.freeze
  SHRINKED_MATCHER = %r[\Ahttp://(bit\.ly|j\.mp)/].freeze

  extend self

  # bitlyユーザ名を返す
  def user
    if UserConfig[:bitly_user] == '' or not UserConfig[:bitly_user]
      USER
    else
      UserConfig[:bitly_user]
    end end

  # bitly API keyを返す
  def apikey
    if UserConfig[:bitly_apikey] == '' or not UserConfig[:bitly_apikey]
      APIKEY
    else
      UserConfig[:bitly_apikey]
    end end

  def expand_url_many(urls)
    query = "login=#{user}&apiKey=#{apikey}&" + urls.map{ |url|
      "shortUrl=#{CGI.escape(url)}" }.join('&')
    3.times do
      result = begin
                 JSON.parse(Net::HTTP.get("api.bit.ly", "/v3/expand?#{query}"))
               rescue Exception
                 nil end
      if result and result['status_code'].to_i == 200
        notice result['data']['expand']
        return Hash[ *result['data']['expand'].map{|token|
                       [token['short_url'], token['long_url']] }.flatten ] end
    end
  end
end

Plugin.create :bitly do
  expand_mutex = Mutex.new
  waiting_expand_entities = TimeLimitedStorage.new(String, Set, 30)

  # URLを展開し、entityを更新する
  # bit.lyの一度のリクエストでexpandできる最大数は15
  # http://code.google.com/p/bitly-api/wiki/ApiDocumentation#/v3/expand
  expand_queue = TimeLimitedQueue.new(15, 0.5, Set) do |set|
    Thread.new {
      expand_mutex.synchronize do
        Plugin::Bitly.expand_url_many(set).each do |shrinked, expanded|
          waiting_expand_entities[shrinked].each do |query|
            begin
              query.call expanded
            rescue => exception
              error exception end end end end
    }.trap{|exception|
      warn exception
      set.each do |url|
        waiting_expand_entities[shrinked].each do
          query.call nil end end
    }.next {
      waiting_expand_entities[shrinked] = Set.new
    }.terminate end

  on_gui_timeline_add_messages do |i_timeline, messages|
    messages.map(&:entity).each do |entity|
      entity.select{|_|
        :urls == _[:slug] and Plugin::Bitly::SHRINKED_MATCHER =~ _[:url]
      }.each do |link|
        notice "detect bitly shrinked url: #{link[:url]} by #{entity.message}"
        expand_mutex.synchronize do
          (waiting_expand_entities[link[:url]] ||= Set.new) << ->expanded{
            entity.add link.merge(url: expanded, face: expanded) }
          expand_queue.push link[:url] end end end end

  filter_expand_url do |urlset|
    divided = urlset.group_by{|url| !!(Plugin::Bitly::SHRINKED_MATCHER =~ url) }
    divided[false] ||= []
    divided[true] ||= []
    [divided[false] + divided[true].each_slice(15).map{|chunk|Plugin::Bitly.expand_url_many(chunk).values}.flatten] end
end

