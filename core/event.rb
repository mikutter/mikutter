# -*- coding: utf-8 -*-

require 'observer'
miquire :core, "delayer"
miquire :lib, "instance_storage"

# イベントの定義。イベントの種類を識別するためのオブジェクト。
class Event
  include Observable
  include InstanceStorage

  # オプション。以下のキーを持つHash
  # :prototype :: 引数の数と型。Arrayで、type_strictが解釈できる条件を設定する
  # :priority :: Delayerの優先順位
  attr_accessor :options

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
      Delayer::ROUTINE_PASSIVE end end

  # イベントを引数 _args_ で発生させる
  # ==== Args
  # [*args] イベントの引数
  # ==== Return
  # Delayerか、イベントを待ち受けているリスナがない場合はnil
  def call(*args)
    Delayer.new(priority) {
      changed
      args = filtering(*args) if not @filters.empty?
      catch(:plugin_exit){ notify_observers(*args) } if args.is_a? Array } end

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

  clear!
end

class EventError < RuntimeError; end
