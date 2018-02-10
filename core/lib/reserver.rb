# -*- coding: utf-8 -*-
=begin rdoc
=Reserver - 指定時間にブロックを実行
指定された時間に一度だけブロックを実行します。調整できる単位は秒です。
アプリケーションが終了するなど、予期せぬ自体が起こると実行されないことがあります。
=end

require 'set'
require 'delegate'

class Reserver < Delegator
  WakeUp = Class.new(Timeout::Error)
  Add = Struct.new(:reserver)
  Delete = Struct.new(:reserver)
  @queue = Thread::Queue.new

  attr_reader :time, :thread_class
  alias __getobj__ time

  def initialize(time, thread: Thread, &proc)
    raise ArgumentError.new('Block necessary for Reserver.new') unless block_given?
    @proc = proc
    @thread_class = thread
    @sequence = :wait
    case time
    when Time
      @time = time.freeze
    when String
      @time = (Time.parse time).freeze
    when Integer
      @time = (Time.new + time).freeze
    else
      raise ArgumentError.new('first argument must be Integer, String or Time')
    end
    Reserver.register(self)
  end

  # コンストラクタに渡したブロックのProcオブジェクトを返す
  def to_proc
    @proc
  end

  # Reserverの実行をキャンセルする。
  # 実行がキャンセルされたReserverはスケジューラから削除され、その時刻になってもブロックが実行されない。
  # このメソッドを呼ぶと、このインスタンスはfreezeされる。
  # 既に実行が完了しているかキャンセルされたものに対して呼んでも何も起きない。
  def cancel
    if !finished?
      @sequence = :cancel
      freeze
      Reserver.unregister(self)
    end
    self
  rescue FrozenError
  end

  # このReserverを実行する時間になっていれば true を返す
  def expired?
    sleep_time <= 0
  end

  # このReserverを何秒後に実行するかを返す
  def sleep_time
    time - Time.now
  end

  # このReserverの処理が既に完了している場合には true を返す
  def finished?
    %i<complete canceled>.include?(@sequence)
  end

  def inspect
    "#<#{self.class} #{@sequence} in #{@proc.source_location&.join(':')} at #{time}>"
  end

  # 内部で呼ぶためのメソッドなので呼ばないでください
  def complete
    @sequence = :complete
    freeze
  rescue FrozenError
  end

  class << self
    def register(reserver)
      @queue.push(Add.new(reserver))
    end

    def unregister(reserver)
      @queue.push(Delete.new(reserver))
    end

    private

    attr_reader :reservers

    def sorted_reservers
      if @sorted
        reservers
      else
        @sorted = true
        reservers.sort_by!(&:time)
      end
    end

    def wait_expired
      next_reserver = fetch
      if next_reserver
        if !next_reserver.expired?
          Timeout.timeout(1 + next_reserver.sleep_time / 2, WakeUp) do
            wait
          end
        end
      else
        wait
      end
    rescue WakeUp
      # ɛ ʘɞʘ ɜ
    end

    def wait
      operation = @queue.pop
      case operation
      when Add
        push(operation.reserver)
      when Delete
        reservers.delete(operation.reserver)
      end
    end

    def fetch
      sorted_reservers[0]
    end

    def pop
      sorted_reservers.shift
    end

    def push(new)
      reservers.unshift(new)
      @sorted = false
    end

    def execute(reserver)
      if !reserver.finished?
        reserver.thread_class.new(&reserver)
        reserver.complete
      end
    end
  end

  @reservers = Array.new
  Thread.new do
    begin
      loop do
        wait_expired
        execute(pop) if fetch&.expired?
      end
    ensure
      @queue.close
    end
  end.abort_on_exception = true
end
