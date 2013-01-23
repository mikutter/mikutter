# -*- coding: utf-8 -*-
require File.expand_path(File.dirname(__FILE__)+'/utils')

# ブロックを、後で時間があいたときに順次実行する。
# 名前deferのほうがよかったんじゃね
class Delayer
  # ユーザのUI入力に対するレスポンスのプライオリティ。
  # 何が何でもこれを最優先にする。
  UI_RESPONSE = 0

  # ユーザの入力によって行われる内部処理。
  ROUTINE_ACTIVE = 1

  # Twitterからのレスポンスなど、外的要因によるUIの更新。
  UI_PASSIVE = 2

  # 外的要因によって発生した内部処理。
  ROUTINE_PASSIVE = 3

  # OBSOLETE
  CRITICAL = 0
  FASTER = 0
  NORMAL = 1
  LATER = 2
  LAST = 2

  extend MonitorMixin
  @@routines = [[],[],[],[]]
  @frozen = false

  attr_reader :backtrace, :status

  class << self
    attr_accessor :exception

    # 登録されたDelayerオブジェクトをいくつか実行する。
    # 0.1秒以内に実行が終わらなければ、残りは保留してとりあえず処理を戻す。
    def run
      return if @frozen
      debugging_wait
      begin
        @busy = true
        @st = Process.times.utime
        @@routines.size.times{ |cnt|
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
      rescue => e
        Delayer.exception = e
        raise e
      ensure
        @busy = false end end


    def time_limit?
      (Process.times.utime - @st) > 0.02 end

    # Delayerのタスクを消化中ならtrueを返す
    def busy?
      @busy end

    # 仕事がなければtrue
    def empty?
      @@routines.all?{|r| r.empty? } end

    # 残っているDelayerの数を返す
    def size
      @@routines.map(&:size).reduce(:+)end

    # このメソッドが呼ばれたら、以後 Delayer.run が呼ばれても、Delayerオブジェクト
    # を実行せずにすぐにreturnするようになる。
    def freeze
      @frozen = true end

    # freezeのはんたい
    def melt
      @frozen = false end

    def on_regist(delayer)
    end end

  # あとで実行するブロックを登録する。
  def initialize(prio = NORMAL, *args, &block)
    @routine = block
    @args = args
    @backtrace = caller
    @status = :wait
    regist(prio)
    Delayer.on_regist(self)
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

  private
  def regist(prio)
    self.class.synchronize{
      @@routines[prio] << self
    }
    Thread.main.wakeup
  end

end

