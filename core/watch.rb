# -*- coding: utf-8 -*-

require File.expand_path('utils')
miquire :core, 'plugin'
miquire :core, 'post'
miquire :core, 'environment'
miquire :core, 'userconfig'

require 'singleton'
require 'set'
require 'pp'

class Watch
  include Singleton

  def self.scan_and_yield(handler)
    lambda {|name, post, options|
      begin
        mumbles = post.scan(handler, options)
        yield(name, post, mumbles) if mumbles
      rescue => e
        warn e
        nil end } end

  def get_events
    @get_events ||= event_factory
    return @get_events end

  def event_factory
    event_booking = Hash.new{ |h, k| h[k] = [] }
    event_add = lambda{ |event, values|
      Plugin.call(event, @post, values) }
    return {
      :period => {
        :interval => 1,
        :proc => lambda {|name, post, messages|
          Plugin.call(name, post) if not messages } },
      :update => {
        :interval => everytime{ UserConfig[:retrieve_interval_friendtl] },
        :options => {:count => everytime{ UserConfig[:retrieve_count_friendtl] } },
        :proc => Watch.scan_and_yield(:friends_timeline){ |name, post, messages|
          if messages.is_a? Array
            event_add.call(:update, messages)
            event_add.call(:mention, messages.select{ |m| m.to_me? })
            event_add.call(:mypost, messages.select{ |m| m.from_me? }) end } },
      :mention => {
        :interval => everytime{ UserConfig[:retrieve_interval_mention] },
        :options => {:count => everytime{ UserConfig[:retrieve_count_mention] } },
        :proc => Watch.scan_and_yield(:replies){ |name, post, messages|
          if messages.is_a? Array
            event_add.call(:update, messages)
            event_add.call(:mention, messages)
            event_add.call(:mypost, messages.select{ |m| m.from_me? }) end } },
    }.freeze end

  def initialize()
    @counter = 0
    @post = Post.new
    @received = Hash.new{ |h, k| h[k] = Set.new }
    Plugin.call(:boot, @post)
  end

  def action
    Thread.new(@counter){ |counter|
      event_threads = []
      get_events.each_pair{ |name, event|
        if((counter % event[:interval]) == 0)
          event_threads << Thread.new{
            event[:proc].call(name, @post, event[:options]) } end }
      event_threads.each &lazy.join
      Plugin.call(:after_event, @post) }
    @counter += 1
  end

  def get_posts(api, options={})
    @post.scan(api, options)
  end

end
