
miquire :plugin, 'plugin'
miquire :core, 'post'
miquire :core, 'utils'
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

  def get_events(&event_add)
    event_booking = Hash.new{ |h, k| h[k] = [] }
    event_add = lambda{ |event, values|
      event_booking[event].concat(values) if values.is_a? Array } if not event_add
    return {
      :period => {
        :interval => 1,
        :proc => lambda {|name, post, messages|
            Plugin.call(name, post) if not messages } },
      :update => {
        :interval => UserConfig[:retrieve_interval_friendtl],
        :options => {:count => UserConfig[:retrieve_count_friendtl]},
        :proc => Watch.scan_and_yield(:friends_timeline){ |name, post, messages|
          if messages.is_a? Array
            event_add.call(:update, messages)
            event_add.call(:mention, messages.select{ |m| m.to_me? })
            event_add.call(:mypost, messages.select{ |m| m.from_me? }) end } },
      :mention => {
        :interval => UserConfig[:retrieve_interval_mention],
        :options => {:count => UserConfig[:retrieve_count_mention]},
        :proc => Watch.scan_and_yield(:replies){ |name, post, messages|
          if messages.is_a? Array
            event_add.call(:update, messages)
            event_add.call(:mention, messages)
            event_add.call(:mypost, messages.select{ |m| m.from_me? }) end } },
    }, lambda{ event_booking } end

  def initialize()
    @counter = 0
    @post = Post.new
    @received = Hash.new{ |h, k| h[k] = Set.new }
    Plugin.call(:boot, @post)
  end

  def action
    events, booking = get_events
    Thread.new(@counter){ |counter|
      threads = ThreadGroup.new
      events.each_pair{ |name, event|
        if((counter % event[:interval]) == 0)
          threads.add Thread.new(name, event){ |name, event|
            event[:proc].call(name, @post, event[:options]) } end }
      threads.list.each{ |t| t.join rescue nil }
      booking.call.each_pair{ |k, v|
        messages = v.uniq.select{ |n| not @received[k].include?(n) }
        @received[k].merge(messages)
        Plugin.call(k, @post, messages) } }
    @counter += 1
  end

  def get_posts(api, options={})
    @post.scan(api, options)
  end

end
