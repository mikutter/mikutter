# -*- coding: utf-8 -*-

miquire :core, "event"

# イベントの発生を待ち受けるオブジェクト
class EventFilter

  # フィルタ内部で使う。フィルタの実行をキャンセルする。Plugin#filtering はfalseを返し、
  # イベントのフィルタの場合は、そのイベントの実行自体をキャンセルする。
  # また、 _result_ が渡された場合、Event#filtering の戻り値は _result_ になる。
  def self.cancel!(result=false)
    throw :filter_exit, result end

  # ==== Args
  # [event] 監視するEventのインスタンス
  # [&callback] コールバック
  def initialize(event, &callback)
    type_strict event => Event, callback => :call
    @event = event
    @callback = callback
    event.add_filter self
  end

  # イベントを実行する
  # ==== Args
  # [*args] イベントの引数
  # ==== Return
  # 加工後の引数の配列
  def filtering(*args)
    length = args.size
    result = @callback.call(*args, &EventFilter.method(:cancel!))
    if length != result.size
      raise EventFilterError, "filter changes arguments length (#{length} to #{result.size})" end
    result end

  # このリスナを削除する
  # ==== Return
  # self
  def detach
    @event.delete_filter(self)
    self end
end

class EventFilterError < EventError; end
