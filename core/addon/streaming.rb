# -*- coding: utf-8 -*-
#
# Revolution!
#

require 'timeout'

Module.new do

  @thread = nil

  plugin = Plugin::create(:streaming)

  plugin.add_event(:boot){ |service|
    @service = service
    start if UserConfig[:realtime_rewind] }

  UserConfig.connect(:realtime_rewind){ |key, new_val, before_val, id|
    if new_val
      Delayer.new{ self.start }
    else
      if @thread
        Plugin.call(:rewindstatus, 'UserStream: disconnected')
        @thread.kill
      else
        Plugin.call(:rewindstatus, 'UserStream: already disconnected. nothing to do.')
      end
    end
  }

  def self.start
    unless @thread and @thread.alive?
      @thread = Thread.new{
        while(UserConfig[:realtime_rewind])
          sleep(3)
          catch(:streaming_break){
            start_streaming{ |q|
              throw(:streaming_break) unless(UserConfig[:realtime_rewind])
              Delayer.new(Delayer::NORMAL, q.strip, &method(:trigger_event)) } }
          Plugin.call(:rewindstatus, 'UserStream: disconnected')
        end } end end

  def self.thread_storage(name)
    @thread_storage ||= Hash.new{|h, k|
      queue = h[k] = Queue.new
      Thread.new{
        while resource = queue.pop
          __send__("event_#{k}", resource)
          sleep(1)
        end
        queue } }
    @thread_storage[name.to_sym] end

  def self.trigger_event(query)
    begin
      return nil if not /^\{.*\}$/ === query
      json = JSON.parse(query)
      case
      when json['friends']
      when respond_to?("event_#{json['event']}")
        thread_storage(json['event']).push(json)
      when json['delete']
        if $debug
          Plugin.call(:update, nil, [Message.new(:message => YAML.dump(json),
                                                 :system => true)]) end
      when !json.has_key?('event')
        messages = @service.__send__(:parse_json, json, :streaming_status)
        if messages
          messages.each{ |msg|
            Plugin.call(:update, @service, [msg])
            Plugin.call(:mention, @service, [msg]) if msg.to_me?
            Plugin.call(:mypost, @service, [msg]) if msg.from_me? }
        elsif $debug
          Plugin.call(:update, nil, [Message.new(:message => YAML.dump(json),
                                                 :system => true)]) end
      when $debug
        Plugin.call(:update, nil, [Message.new(:message => YAML.dump(json),
                                               :system => true)])
      end
    rescue Exception => e
      notice e
    end end

  def self.event_favorite(json)
    by = @service.__send__(:parse_json, json['source'], :user_show)
    to = @service.__send__(:parse_json, json['target_object'], :status_show)
    to.first.add_favorited_by(by.first, Time.parse(json['created_at']))
  end

  def self.event_unfavorite(json)
    by = @service.__send__(:parse_json, json['source'], :user_show)
    to = @service.__send__(:parse_json, json['target_object'], :status_show)
    to.first.remove_favorited_by(by.first)
  end

  def self.event_follow(json)
    source = @service.__send__(:parse_json, json['source'], :user_show).first
    target = @service.__send__(:parse_json, json['target'], :user_show).first
    if(target.is_me?)
      Plugin.call(:followers_created, @service, [source])
    elsif(source.is_me?)
      Plugin.call(:followings_created, @service, [target]) end end

  def self.start_streaming(&proc)
    begin
      Plugin.call(:rewindstatus, 'UserStream: start')
      @service.streaming(&proc)
    rescue Exception => e
      Plugin.call(:rewindstatus, "UserStream: fault (#{e.class.to_s})")
      error e
    end
  end
end

