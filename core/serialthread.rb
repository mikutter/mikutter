# -*- coding: utf-8 -*-

require File.expand_path(File.join(File.dirname(__FILE__), 'utils'))
miquire :lib, 'delayer'

require 'set'
require 'thread'
require 'timeout'

# 渡されたブロックを順番に実行するクラス
class SerialThreadGroup
  QueueExpire = Class.new(TimeoutError)

  # ブロックを同時に処理する個数。最大でこの数だけThreadが作られる
  attr_accessor :max_threads

  @@force_exit = false

  def initialize
    @lock = Monitor.new
    @queue = Queue.new
    @max_threads = 1
    @thread_pool = Set.new
  end

  # 実行するブロックを新しく登録する
  def push(proc=Proc.new)
    return if @@force_exit
    @lock.synchronize{
      @queue.push(proc)
      new_thread if 0 == @queue.num_waiting and @thread_pool.size < max_threads } end
  alias new push

  # 処理中なら真
  def self.busy?
    @thread_pool.any?{ |t| :run == t.status.to_sym } end

  # 全てのserial threadの実行をキャンセルする。終了時の処理用
  def self.force_exit!
    notice "all Serial Thread Group jobs canceled."
    @@force_exit = true end

  private

  # Threadが必要なら一つ立ち上げる。
  # これ以上Threadが必要ない場合はtrueを返す。
  def flush
    return true if @@force_exit
    @lock.synchronize{
      @thread_pool.delete_if{ |t| not t.alive? }
      if @thread_pool.size > max_threads
        return true
      elsif 0 == @queue.num_waiting and @thread_pool.size < max_threads
        new_thread end }
    false end

  def new_thread
    return if @@force_exit
    @thread_pool << Thread.new{
      begin
        while proc = timeout(1, QueueExpire){ @queue.pop }
          break if @@force_exit
          proc.call
          break if flush
          debugging_wait
          Thread.pass end
      rescue QueueExpire => e
        ;
      rescue Object => e
        error e
        abort
      ensure
        @lock.synchronize{
          @thread_pool.delete(Thread.current) } end } end

end

# SerialThreadGroup のインスタンス。
# 同時実行数は1固定
SerialThread = SerialThreadGroup.new

