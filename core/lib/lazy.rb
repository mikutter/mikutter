# -*- coding: utf-8 -*-

=begin rdoc
遅延評価オブジェクト。
インスタンスのメソッドが呼ばれると、コンストラクタに渡されたブロックが実行され、その戻り値のメソッドに
処理が移譲される。
二回目以降は、初回のブロックの実行結果に対してメソッドが移譲される。
=end
class Lazy
  def initialize
    @proc = Proc.new
    @obj = nil end

  def self.define_bridge(method, *remain)
    define_method(method){ |*args, &proc|
      method_missing(method, *args, &proc) }
    define_bridge(*remain) if not remain.empty?
  end

  define_bridge(*Object.methods)

  def method_missing(method, *args, &block)
    if @proc
      @obj = @proc.call
      @proc = nil end
    @obj.__send__(method, *args, &block) end end

# 毎回評価
# Lazyの、呼び出しごとにブロックを評価するバージョン。
class EveryTime < Lazy
  def method_missing(method, *args, &block)
    @proc.call.__send__(method, *args, &block) end end

# 平行評価
# このインスタンスはすぐに別スレッドでブロックの評価が始まり、そのブロックの戻り値として振舞う。
# ただし、ブロックの処理が終わる前にこのオブジェクトを参照した場合、参照元のスレッドは値が返るまで
# ブロッキングされる
class Parallel < Lazy
  def initialize
    @proc = Thread.new{ yield }
    @obj = nil end

  def method_missing(method, *args, &block)
    if @proc
      @obj = @proc.value
      @proc = nil end
    @obj.__send__(method, *args, &block) end end

# 遅延評価オブジェクトを作成する
def lazy(&proc)
  Lazy.new(&proc) end

def everytime(&proc)
  EveryTime.new(&proc) end

def parallel(&proc)
  Parallel.new(&proc) end
