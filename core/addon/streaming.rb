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
          sleep((UserConfig[:"#{event_name}_queue_delay"] || 100).to_f / 1000)
          datum = queue.pop
          yield(service, datum) } }
      define_method("event_#{event_name}"){ |json|
        type_strict json => tcor(Array, Hash)
        service ||= @service
        queue << json } end

    def self.define_together_event(event_name)
      type_strict event_name => tcor(Symbol, String)
      speed_key = "#{event_name}_queue_delay".to_sym
      queue = TimeLimitedQueue.new(HYDE, (UserConfig[speed_key] || 100).to_f / 1000) { |data|
        yield @service, data }
      UserConfig.connect(speed_key) { |key, val|
        notice "change #{key} #{val}"
        queue.expire = (val || 100).to_f / 1000 }
      define_method("event_#{event_name}"){ |json|
        type_strict json => tcor(Array, Hash)
        queue.push json } end

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
        when json['direct_message']
          event_direct_message(json['direct_message'])
        when json['delete']
          if Mopt.debug
            Plugin.activity :system, YAML.dump(json) end

        when !json.has_key?('event')
          # thread_storage(:update).push(json)
          event_update(json)
        when Mopt.debug
          Plugin.activity :system, YAML.dump(json)
        end
      rescue Exception => e
        Plugin.activity :error, e.to_s, exception: e
        notice e
      end end

    define_together_event(:update) do |service, data|
      events = Hash.new{ |h, k| h[k] = Set.new }
      data.each{ |datum|
        pack_message_event(MikuTwitter::ApiCallSupport::Request::Parser.message(datum.symbolize), events) }
      trigger_event(service, events) end

    def self.pack_message_event(msg, buffer=Hash.new)
      type_strict msg => Message
      buffer[:update] << msg
      buffer[:mention] << msg if msg.to_me?
      buffer[:mypost] << msg if msg.from_me?
      buffer end

    def self.trigger_event(service, events)
      events.each{ |event_name, data|
        Plugin.call(event_name, service, data) } end

    define_together_event(:direct_message) do |service, data|
      trigger_event(service, :direct_messages => data.map{ |datum|
                      MikuTwitter::ApiCallSupport::Request::Parser.direct_message(datum.symbolize) }) end

    define_event(:favorite) do |service, json|
      by = MikuTwitter::ApiCallSupport::Request::Parser.user(json['source'].symbolize)
      to = MikuTwitter::ApiCallSupport::Request::Parser.message(json['target_object'].symbolize)
      if(to.respond_to?(:add_favorited_by))
        to.add_favorited_by(by, Time.parse(json['created_at'])) end end

    define_event(:unfavorite) do |service, json|
      by = MikuTwitter::ApiCallSupport::Request::Parser.user(json['source'].symbolize)
      to = MikuTwitter::ApiCallSupport::Request::Parser.message(json['target_object'].symbolize)
      if(to.respond_to?(:remove_favorited_by))
        to.remove_favorited_by(by) end end

    define_event(:follow) do |service, json|
      source = MikuTwitter::ApiCallSupport::Request::Parser.user(json['source'].symbolize)
      target = MikuTwitter::ApiCallSupport::Request::Parser.user(json['target'].symbolize)
      if(target.is_me?)
        Plugin.call(:followers_created, service, [source])
      elsif(source.is_me?)
        Plugin.call(:followings_created, service, [target]) end end

    define_event(:list_member_added) do |service, json|
      target_user = MikuTwitter::ApiCallSupport::Request::Parser.user(json['target'].symbolize) # リストに追加されたユーザ
      list = MikuTwitter::ApiCallSupport::Request::Parser.list(json['target_object'].symbolize) # リスト
      source_user = MikuTwitter::ApiCallSupport::Request::Parser.user(json['source'].symbolize) # 追加したユーザ
      list.add_member(target_user)
      Plugin.call(:list_member_added, service, target_user, list, source_user)
    end

    define_event(:list_member_removed) do |service, json|
      target_user = MikuTwitter::ApiCallSupport::Request::Parser.user(json['target'].symbolize) # リストに追加されたユーザ
      list = MikuTwitter::ApiCallSupport::Request::Parser.list(json['target_object'].symbolize) # リスト
      source_user = MikuTwitter::ApiCallSupport::Request::Parser.user(json['source'].symbolize) # 追加したユーザ
      list.remove_member(target_user)
      Plugin.call(:list_member_removed, service, target_user, list, source_user)
    end

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
