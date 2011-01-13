# -*- coding: utf-8 -*-

require 'thread'

# コンストラクタにブロックを与えると別スレッドでそれを実行するが、
# 別々のSerialThread同士は同じスレッドで実行される
class SerialThread
  @@wait_queue = Queue.new
  @@rapid_queue = Queue.new

  def self.new_thread(queue, wait_finish_delayer)
    Thread.new do
      begin
        while proc = queue.pop
          proc.call
          if(wait_finish_delayer)
            while not(Delayer.empty?)
              sleep(0.1) end end end
      rescue Object => e
        error e
        abort end end end

  new_thread(@@wait_queue, true)
  new_thread(@@rapid_queue, false)

  # SerialThread.new(false) と同じ
  def self.rapid
    self.new(false, &Proc.new) end

  # SerialThread.new(true) と同じ
  def self.lator
    self.new(true, &Proc.new) end

  # SerialThreadの
  def self.new(wait_finish_delayer = true)
    (wait_finish_delayer ? @@wait_queue : @@rapid_queue).push(Proc.new)
    nil end end
