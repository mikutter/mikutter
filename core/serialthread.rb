# -*- coding: utf-8 -*-

require File.expand_path(File.join(File.dirname(__FILE__), 'utils'))
miquire :core, 'delayer'

require 'thread'

# コンストラクタにブロックを与えると別スレッドでそれを実行するが、
# 別々のSerialThread同士は同じスレッドで実行される（複数のSerialThreadは同時に実行されない）
class SerialThread
  @wait_queue = Queue.new
  @rapid_queue = Queue.new
  @lock = Mutex.new

  # SerialThreadの中でブロックを実行する。
  def self.new(wait_finish_delayer = true)
    (wait_finish_delayer ? @wait_queue : @rapid_queue).push(Proc.new)
    nil end

  # SerialThread.new(false) と同じ
  def self.rapid
    self.new(false, &Proc.new) end

  # SerialThread.new(true) と同じ
  def self.lator
    self.new(true, &Proc.new) end

  def self.busy?
    @lock.locked? end

  def self.new_thread(queue, wait_finish_delayer)
    Thread.new do
      begin
        while proc = queue.pop
          @lock.synchronize{ proc.call }
          sleep(0.1) while Delayer.busy? if wait_finish_delayer end
      rescue Object => e
        error e
        abort end end end

  new_thread(@wait_queue, true)
  new_thread(@rapid_queue, false)

end
