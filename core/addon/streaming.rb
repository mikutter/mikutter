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

  class << self

    def self.define_event(event_name)
      type_strict event_name => tcor(Symbol, String)
      queue = Queue.new
      service = nil
      Thread.new{
        sleep(1) while not service
        loop{
          datum = queue.pop
          yield(service, datum)
          sleep(1) } }
      define_method("event_#{event_name}"){ |json|
        type_strict json => tcor(Array, Hash)
        service ||= @service
        queue << json } end

    def self.define_together_event(event_name)
      type_strict event_name => tcor(Symbol, String)
      lock = Mutex.new
      events = Set.new
      service = nil
      thread = Thread.new{
        sleep(1) while not service
        loop{
          Thread.stop if events.empty?
          yield(service, lock.synchronize{ data = events; events = Set.new; data.freeze })
          sleep(1) } }
      define_method("event_#{event_name}"){ |json|
        type_strict json => tcor(Array, Hash)
        service ||= @service
        lock.synchronize{ events << json }
        thread.wakeup } end

    def start
      unless @thread and @thread.alive?
        @thread = Thread.new{
          while(UserConfig[:realtime_rewind])
            sleep(3)
            catch(:streaming_break){
              start_streaming{ |q|
                throw(:streaming_break) unless(UserConfig[:realtime_rewind])
                # Delayer.new(Delayer::NORMAL, q.strip, &method(:trigger_event))
                trigger_event(q.strip) } }
            Plugin.call(:rewindstatus, 'UserStream: disconnected')
          end } end end

    def trigger_event(query)
      begin
        return nil if not /^\{.*\}$/ === query
        json = JSON.parse(query)
        case
        when json['friends']
        when respond_to?("event_#{json['event']}")
          __send__(:"event_#{json['event']}", json)
          # thread_storage(json['event']).push(json)
        when json['delete']
          if $debug
            Plugin.call(:update, nil, [Message.new(:message => YAML.dump(json),
                                                   :system => true)]) end
        when !json.has_key?('event')
          # thread_storage(:update).push(json)
          event_update(json)
        when $debug
          Plugin.call(:update, nil, [Message.new(:message => YAML.dump(json),
                                                 :system => true)])
        end
      rescue Exception => e
        notice e
      end end

    define_together_event(:update) do |service, data|
      events = Hash.new{ |h, k| h[k] = Set.new }
      data.each{ |datum|
        pack_message_event(service.__send__(:parse_json, datum, :streaming_status), events) }
      trigger_event(service, events) end

    def self.pack_message_event(messages, buffer=Hash.new)
      messages.each{ |msg|
        type_strict msg => Message
        buffer[:update] << msg
        buffer[:mention] << msg if msg.to_me?
        buffer[:mypost] << msg if msg.from_me? }
      buffer end

    def self.trigger_event(service, events)
      events.each{ |event_name, data|
        Plugin.call(event_name, service, data) } end

    define_event(:favorite) do |service, json|
      by = service.__send__(:parse_json, json['source'], :user_show)
      to = service.__send__(:parse_json, json['target_object'], :status_show)
      if(by.respond_to?(:first) and to.respond_to?(:first) and to.first.respond_to?(:add_favorited_by))
        to.first.add_favorited_by(by.first, Time.parse(json['created_at'])) end end

    define_event(:unfavorite) do |service, json|
      by = service.__send__(:parse_json, json['source'], :user_show)
      to = service.__send__(:parse_json, json['target_object'], :status_show)
      if(by.respond_to?(:first) and to.respond_to?(:first) and to.first.respond_to?(:remove_favorited_by))
        to.first.remove_favorited_by(by.first) end end

    define_event(:follow) do |service, json|
      source = service.__send__(:parse_json, json['source'], :user_show).first
      target = service.__send__(:parse_json, json['target'], :user_show).first
      if(target.is_me?)
        Plugin.call(:followers_created, service, [source])
      elsif(source.is_me?)
        Plugin.call(:followings_created, service, [target]) end end

    def start_streaming(&proc)
      begin
        Plugin.call(:rewindstatus, 'UserStream: start')
        @service.streaming(&proc)
      rescue Exception => e
        Plugin.call(:rewindstatus, "UserStream: fault (#{e.class.to_s})")
        error e
      end
    end
  end
end
