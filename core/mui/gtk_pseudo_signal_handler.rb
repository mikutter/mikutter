# -*- coding: utf-8 -*-

=begin rdoc
  どんなオブジェクトでも、GLib::Objectのように、signalを発生させたり設定したりできるようにするモジュール。
=end
module PseudoSignalHandler

  # シグナル _signal_ に、ハンドラを登録する。シグナルIDを返す。
  def signal_connect(signal, proc=Proc.new)
    __signals[signal.to_sym] << proc
    proc.__id__ end

  # シグナルID _sid_ の登録を解除する
  def signal_handler_disconnect(sid)
    __signals.each{ |pair|
      break if pair.last.reject!{ |handler| handler.__id__ == sid } }
    self end

  # シグナル _signal_ を発生させる。
  # シグナルには、第一引数に _self_ 、第二引数以降に _args_ が渡される。
  def signal_emit(signal, *args)
    __signals[signal.to_sym].each{ |handler|
      Delayer.new{
        if not destroyed?
          handler.call(*[self, *args][0, (handler.arity <= -1 ? (args.size + 1) : handler.arity)]) end } }
    self end

  private

  def __signals
    @__signals ||= Hash.new{ |h, k| h[k] = [] } end

end
