# -*- coding: utf-8 -*-

miquire :core, "event"

# イベントの発生を待ち受けるオブジェクト
class EventListener
  # プラグインコールバックをこれ以上実行しない。
  def self.cancel!
    throw :plugin_exit, false end

  # ==== Args
  # [event] 監視するEventのインスタンス
  # [&callback] コールバック
  def initialize(event, &callback)
    type_strict event => Event, callback => :call
    @event = event
    @callback = callback
    event.add_observer self
  end

  # イベントを実行する
  # ==== Args
  # [*args] イベントの引数
  def update(*args)
    @callback.call(*args, &EventListener.method(:cancel!)) end

  # このリスナを削除する
  # ==== Return
  # self
  def detach
    count = @event.count_observers
    @event.delete_observer(self)
    self end
end
