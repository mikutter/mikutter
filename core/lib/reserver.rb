# -*- coding: utf-8 -*-
=begin rdoc
=Recerve - 指定時間にブロックを実行
指定された時間に一度だけブロックを実行します。調整できる単位は秒です。
アプリケーションが終了するなど、予期せぬ自体が起こると実行されないことがあります。
=end

require 'set'
require 'delegate'

class Reserver < Delegator

  attr_reader :time
  alias __getobj__ time

  def initialize(time, &proc)
    raise ArgumentError.new('Block necessary for Reserver.new') unless block_given?
    @proc = proc
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
    Reserver.regist(self)
  end

  def call
    @proc.call
    self end

  def to_proc
    @proc end

  class << self
    WakeUp = Class.new(TimeoutError)

    def regist(new)
      atomic do
        (@recervers ||= SortedSet.new) << new
        waiter.run end end

    def waiter
      atomic do
        @waiter = nil if @waiter and not @waiter.alive?
        @waiter ||= Thread.new do
          while !@recervers.empty?
            begin
              recerver = @recervers.first
              sleep_time = recerver.time - Time.now
              if sleep_time <= 0
                @recervers.delete recerver
                Thread.new(&recerver)
              else
                timeout(1 + sleep_time / 2, WakeUp){ Thread.stop } end
            rescue WakeUp
              ;
            rescue Exception => e
              warn e end end end end end

  end
end
