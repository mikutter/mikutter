# -*- coding: utf-8 -*-
=begin rdoc
=Recerve - 指定時間にブロックを実行
指定された時間に一度だけブロックを実行します。調整できる単位は秒です。
アプリケーションが終了するなど、予期せぬ自体が起こると実行されないことがあります。
=end

require 'set'
require 'delegate'

class Reserver < Delegator

  attr_reader :time, :thread_class
  alias __getobj__ time

  def initialize(time, thread: Thread, &proc)
    raise ArgumentError.new('Block necessary for Reserver.new') unless block_given?
    @proc = proc
    @thread_class = thread
    case
    when time.is_a?(Time)
      @time = time.freeze
    when time.is_a?(String)
      @time = (Time.parse time).freeze
    when time.is_a?(Integer)
      @time = (Time.new + time).freeze
    else
      raise ArgumentError.new('first argument must be Integer, String or Time')
    end
    Reserver.register(self)
  end

  def call
    @proc.call
    self end

  def to_proc
    @proc end

  def cancel
    Reserver.unregister(self)
  end

  class << self
    WakeUp = Class.new(Timeout::Error)

    def register(new)
      atomic do
        (@reservers ||= SortedSet.new) << new
        waiter.run end end

    def unregister(reserver)
      @reservers.delete(reserver)
    end

    def waiter
      atomic do
        @waiter = nil if @waiter and not @waiter.alive?
        @waiter ||= Thread.new do
          while !@reservers.empty?
            begin
              reserver = @reservers.first
              sleep_time = reserver.time - Time.now
              if sleep_time <= 0
                @reservers.delete reserver
                reserver.thread_class.new(&reserver)
              else
                Timeout.timeout(1 + sleep_time / 2, WakeUp){ Thread.stop } end
            rescue WakeUp
              ;
            rescue Exception => e
              warn e end end end end end

  end
end
