# -*- coding: utf-8 -*-
require 'thread'
require File.expand_path File.join(File.dirname(__FILE__), 'streamer_error')

module ::Plugin::Streaming
  class Streamer
    attr_reader :thread, :service

    # イベントを登録する
    # ==== Args
    # [name] イベント名
    # [many] オブジェクトをまとめて配列で受け取るかどうか
    # [&proc] イベントを受け取るオブジェクト。
    def self.defevent(name, many=false, &proc)
      speed_key = "#{name}_queue_delay".to_sym
      define_method("_event_#{name}", &proc)
      if many
        define_method("event_#{name}"){ |json|
          @queue[name] ||= TimeLimitedQueue.new(HYDE, everytime{ (UserConfig[speed_key] || 100).to_f / 1000 }){ |data|
            begin
              __send__("_event_#{name}", data)
            rescue Exception => e
              warn e end }
          @threads[name] ||= everytime{ @queue[name].thread }
          @queue[name].push json }
      else
        define_method("event_#{name}"){ |json|
          @queue[name] ||= _queue = Queue.new
          @threads[name] ||= Thread.new{
            loop{
              begin
                sleep((UserConfig[speed_key] || 100).to_f / 1000)
                __send__("_event_#{name}", @queue[name].pop)
              rescue Exception => e
                warn e end } }
          queue_push(name, json) } end end

    # ==== Args
    # [service] 接続するService
    # [on_connect] 接続されたら呼ばれる
    def initialize(service, &on_connect)
      @service = service
      @thread = Thread.new(&method(:mainloop))
      @on_connect = on_connect
      @threads = {}
      @queue = {} end

    def mainloop
      service.streaming{ |q|
        if q and not q.empty?
          parsed = JSON.parse(q) rescue nil
          event_factory parsed if parsed end }
    rescue => e
      notice e
      raise e end

    # UserStreamを終了する
    def kill
      @thread.kill
      @threads.each{ |event, thread|
        thread.kill }
      @threads.clear
      @queue.clear end

    private

    # イベント _name_ のキューに値 _data_ を追加する。
    # ==== Args
    # [name] イベント名
    # [data] キューに入れる値
    # ==== Exception
    # キューを処理するスレッドが正常終了している場合、 Plugin::Streaming::StreamerError を発生させる。
    # 異常終了している場合は、その例外をそのまま発生させる。
    def queue_push(name, data)
      if @threads[name] && @threads[name]
        if @threads[name].alive?
          @queue[name].push data
        else
          if @threads[name].status.nil?
            @queue[name].thread.status.join
          else
            raise Plugin::Streaming::StreamerError, "event '#{name}' thread is dead." end end end end

    # UserStreamで流れてきた情報を処理する
    # ==== Args
    # [parsed] パースされたJSONオブジェクト
    def event_factory(json)
      json.freeze
      case
      when json['friends']
        if @on_connect
          @on_connect.call(json)
          @on_connect = nil end
      when respond_to?("event_#{json['event']}")
        __send__(:"event_#{json['event']}", json)
      when json['direct_message']
        event_direct_message(json['direct_message'])
      when json['delete']
        # if Mopt.debug
        #   Plugin.activity :system, YAML.dump(json)
        # end
      when !json.has_key?('event')
        event_update(json)
      when Mopt.debug
        Plugin.activity :system, YAML.dump(json)
      else
        if Mopt.debug
          Plugin.activity :system, "unsupported event:\n" + YAML.dump(json) end end end

    defevent(:update, true) do |data|
      events = {update: Messages.new, mention: Messages.new, mypost: Messages.new}
      data.each { |json|
        msg = MikuTwitter::ApiCallSupport::Request::Parser.message(json.symbolize)
        events[:update] << msg
        events[:mention] << msg if msg.to_me?
        events[:mypost] << msg if msg.from_me? }
      events.each{ |event_name, data|
        Plugin.call(event_name, @service, data.freeze) } end

    defevent(:direct_message, true) do |data|
      Plugin.call(:direct_messages, @service, data.map{ |datum| MikuTwitter::ApiCallSupport::Request::Parser.direct_message(datum.symbolize) }) end

    defevent(:favorite) do |json|
      by = MikuTwitter::ApiCallSupport::Request::Parser.user(json['source'].symbolize)
      to = MikuTwitter::ApiCallSupport::Request::Parser.message(json['target_object'].symbolize)
      if(to.respond_to?(:add_favorited_by))
        to.add_favorited_by(by, Time.parse(json['created_at'])) end end

    defevent(:unfavorite) do |json|
      by = MikuTwitter::ApiCallSupport::Request::Parser.user(json['source'].symbolize)
      to = MikuTwitter::ApiCallSupport::Request::Parser.message(json['target_object'].symbolize)
      if(to.respond_to?(:remove_favorited_by))
        to.remove_favorited_by(by) end end

    defevent(:follow) do |json|
      source = MikuTwitter::ApiCallSupport::Request::Parser.user(json['source'].symbolize)
      target = MikuTwitter::ApiCallSupport::Request::Parser.user(json['target'].symbolize)
      if(target.is_me?)
        Plugin.call(:followers_created, @service, Users.new([source]))
      elsif(source.is_me?)
        Plugin.call(:followings_created, @service, Users.new([target])) end end

    defevent(:list_member_added) do |json|
      target_user = MikuTwitter::ApiCallSupport::Request::Parser.user(json['target'].symbolize) # リストに追加されたユーザ
      list = MikuTwitter::ApiCallSupport::Request::Parser.list(json['target_object'].symbolize) # リスト
      source_user = MikuTwitter::ApiCallSupport::Request::Parser.user(json['source'].symbolize) # 追加したユーザ
      list.add_member(target_user)
      Plugin.call(:list_member_added, @service, target_user, list, source_user) end

    defevent(:list_member_removed) do |json|
      target_user = MikuTwitter::ApiCallSupport::Request::Parser.user(json['target'].symbolize) # リストに追加されたユーザ
      list = MikuTwitter::ApiCallSupport::Request::Parser.list(json['target_object'].symbolize) # リスト
      source_user = MikuTwitter::ApiCallSupport::Request::Parser.user(json['source'].symbolize) # 追加したユーザ
      list.remove_member(target_user)
      Plugin.call(:list_member_removed, @service, target_user, list, source_user) end

  end
end
