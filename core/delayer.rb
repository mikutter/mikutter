# -*- coding: utf-8 -*-
require File.expand_path('utils')

# ブロックを、後で時間があいたときに順次実行する。
# 名前deferのほうがよかったんじゃね
class Delayer
  CRITICAL = 0
  FASTER = 0
  NORMAL = 1
  LATER = 2
  LAST = 2
  extend MonitorMixin
  @@routines = [[],[],[]]
  @frozen = false

  attr_reader :backtrace, :status

  # あとで実行するブロックを登録する。
  def initialize(prio = NORMAL, *args, &block)
    @routine = block
    @args = args
    @backtrace = caller
    @status = :wait
    regist(prio)
  end

  # このDelayerを取り消す。処理が呼ばれる前に呼べば、処理をキャンセルできる
  def reject
    @status = nil
  end

  # このブロックを実行する。内部で呼ぶためにあるので、明示的に呼ばないこと
  def run
    return if @status != :wait
    @status = :run
    begin
      @routine.call(*@args)
    rescue Exception => e
      now = caller.size + 1     # @routine.callのぶんスタックが１つ多い
      $@ = e.backtrace[0, e.backtrace.size - now] + @backtrace
      raise e
    end
    @routine = nil
    @status = nil
  end

  # 登録されたDelayerオブジェクトをいくつか実行する。
  # 0.1秒以内に実行が終わらなければ、残りは保留してとりあえず処理を戻す。
  def self.run
    return if @frozen
    debugging_wait
    begin
      @busy = true
    @st = Process.times.utime
    3.times{ |cnt|
      procs = []
      if not @@routines[cnt].empty? then
        procs = @@routines[cnt].clone
        procs.each{ |routine|
            @@routines[cnt].delete(routine)
            if Mopt.debug
              r_start = Process.times.utime
              routine.run
              if (r_end = Process.times.utime - r_start) > 0.1
                bt = routine.backtrace.find{ |bt| not bt.include?('delayer') }
                bt = routine.backtrace.first if not bt
                Plugin.call(:processtime, :delayer, "#{"%.2f" % r_end},#{bt.gsub(FOLLOW_DIR, '{MIKUTTER_DIR}')}")
              end
            else
              routine.run end
            return if time_limit? } end }
    ensure
      @busy = false end end

  def self.time_limit?
    (Process.times.utime - @st) > 0.02 end

  # Delayerのタスクを消化中ならtrueを返す
  def self.busy?
    @busy end

  # 仕事がなければtrue
  def self.empty?
    @@routines.all?{|r| r.empty? } end

  # 残っているDelayerの数を返す
  def self.size
    @@routines.map{|r| r.size }.sum end


  # このメソッドが呼ばれたら、以後 Delayer.run が呼ばれても、Delayerオブジェクト
  # を実行せずにすぐにreturnするようになる。
  def self.freeze
    @frozen = true
  end

  # freezeのはんたい
  def self.melt
    @frozen = false
  end

  private
  def regist(prio)
    self.class.synchronize{
      @@routines[prio] << self
    }
  end

end

