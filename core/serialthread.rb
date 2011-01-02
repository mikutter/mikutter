# -*- coding: utf-8 -*-

require 'thread'

# コンストラクタにブロックを与えると別スレッドでそれを実行するが、
# 別々のSerialThread同士は同じスレッドで実行される
class SerialThread
  @@q = Queue.new

  Thread.new do
    while proc = @@q.pop
      proc.call
      Thread.pass
      notice "waiting: #{@@q.size}"
      while not(Delayer.empty?)
        notice "blocking: delayer exists"
        sleep(0.1)
        Thread.pass end
    end end

  def self.new
    @@q.push(Proc.new)
    nil end end
