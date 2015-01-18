# -*- coding: utf-8 -*-

require 'observer'
miquire :lib, "instance_storage", "delayer", 'deferred', 'serialthread'

# イベントの定義。イベントの種類を識別するためのオブジェクト。
class Event
  include Observable
  include InstanceStorage

  # オプション。以下のキーを持つHash
  # :prototype :: 引数の数と型。Arrayで、type_strictが解釈できる条件を設定する
  # :priority :: Delayerの優先順位
  attr_accessor :options

  # フィルタを別のスレッドで実行する。偽ならメインスレッドでフィルタを実行する
  @filter_another_thread = false

  def initialize(*args)
    super
    @options = {}
    @filters = [] end

  # イベントの優先順位を取得する
  # ==== Return
  # プラグインの優先順位
  def priority
    if @options.has_key? :priority
      @options[:priority]
    else
      :routine_passive end end

  # イベントを引数 _args_ で発生させる
  # ==== Args
  # [*args] イベントの引数
  # ==== Return
  # self
  def call(*args)
    prototype = @options.has_key? :prototype
    type_strict args.zip(@options[:prototype]) if prototype

    if Event.filter_another_thread
      if @filters.empty?
        Delayer.new(priority) {
          changed
          catch(:plugin_exit){ notify_observers(*args) } }
      else
        filter_thread = Thread.new do
          filtering(*args) end
        Delayer.new do
          filtered_args = filter_thread.join.value
          filter_thread = nil
          if filtered_args.is_a? Array
            changed
            catch(:plugin_exit){ notify_observers(*filtered_args) } end end
      end
    else
      Delayer.new(priority) {
        changed
        args = filtering(*args) if not @filters.empty?
        catch(:plugin_exit){ notify_observers(*args) } if args.is_a? Array } end end

  # 引数 _args_ をフィルタリングした結果を返す
  # ==== Args
  # [*args] 引数
  # ==== Return
  # フィルタされた引数の配列
  def filtering(*args)
    catch(:filter_exit) {
      @filters.reduce(args){ |args, event_filter|
        event_filter.filtering(*args) } } end

  # イベントフィルタを追加する
  # ==== Args
  # [event_filter] イベントフィルタ(EventFilter)
  # ==== Return
  # self
  def add_filter(event_filter)
    type_strict event_filter => EventFilter
    @filters << event_filter
    self end

  # イベントフィルタを削除する
  # ==== Args
  # [event_filter] イベントフィルタ(EventFilter)
  # ==== Return
  # self
  def delete_filter(event_filter)
    @filters.delete(event_filter)
    self end

  class << self
    attr_accessor :filter_another_thread

    alias __clear_aF4e__ clear!
    def clear!
      @filter_another_thread = false
      __clear_aF4e__()
    end
  end

  clear!
end

class EventError < RuntimeError; end
