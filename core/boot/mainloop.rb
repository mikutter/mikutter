# -*- coding: utf-8 -*-

module Mainloop
  extend Mainloop

  # メインループ実行前に呼ばれる
  def before_mainloop
  end

  # メインループ本体
  def mainloop
    loop{
      Thread.stop if Delayer.empty?
      Delayer.run while not Delayer.empty? } end

  # メインループ中に発生した例外を受け取る
  # ==== Args
  # [e] Exception
  # ==== Return
  # e
  def exception_filter(e)
    e end

end
