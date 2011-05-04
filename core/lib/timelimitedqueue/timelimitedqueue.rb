# -*- coding: utf-8 -*-
=begin rdoc
コールバック機能付きキュー。コンストラクタに渡したブロックが、pushされた値の集合を引数に呼ばれる。
コールバックは、以下の条件の何れかを満たしたときに動く。
1. キューの個数が _max_ を超えたとき
2. キューに _expire_ 秒以上値の追加が無かったとき
ただし、何らかの理由で一度にコールバックに渡される値の数は _max_ 個を超える場合がある。
=end

require 'thread'
require 'timeout'

class TimeLimitedQueue < Queue

  TLQGroup = ThreadGroup.new

  # 一度にキューを処理する上限を取得設定する
  attr_accessor :max

  # キューの待ち時間のリミットを取得設定する
  attr_accessor :expire

  # コールバックに渡すためのクラスを取得設定する。
  # 通常Arrayだが、Setにすれば同じ値が同時に二つ入らない代わりに、高速に処理される。
  # メソッド _push_ を実装しているクラスを指定する。
  attr_accessor :strage_class

  attr_reader :thread # :nodoc:

  END{
    p TLQGroup.list
    TLQGroup.list.each{ |thread|
      thread.kill if thread.alive?
      p thread[:queue]
      thread[:queue].instance_eval{ callback } } }

  def initialize(max=1024, expire=5, storage_class=Array, proc=Proc.new) # :yield: data
    @thread = nil
    @callback = proc
    @max = max
    @expire = expire
    @storage_class = storage_class
    @stock = @storage_class.new
    super()
  end

  # 値 _value_ をキューに追加する。
  def push(value)
    result = super(value)
    pushed_event
    result end
  undef_method(:enq, :<<)

  private

  # 待機中のスレッド内の処理
  def waiting_proc
    TLQGroup.add(Thread.current)
    loop do
      catch(:write){
        loop{
          begin
            timeout(expire){ @stock.push(pop) }
          rescue Timeout::Error
            throw :write end
          if @stock.size > max
            throw :write end } }
      callback if not @stock.empty?
      break if empty? end
  end

  def callback
    @stock.push(pop) while not empty?
    @callback.call(@stock.freeze)
    @stock = @storage_class.new end

  # キューに値が追加された時のイベント
  def pushed_event
      if not(@thread and @thread.alive?)
        @thread = Thread.new(&method(:waiting_proc))
        TLQGroup.add(@thread)
        @thread[:queue] = self
        @thread.abort_on_exception = true
      end end

end
