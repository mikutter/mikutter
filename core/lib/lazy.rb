# -*- coding: utf-8 -*-

=begin rdoc
遅延評価オブジェクト。
インスタンスのメソッドが呼ばれると、コンストラクタに渡されたブロックが実行され、その戻り値のメソッドに
処理が移譲される。
二回目以降は、初回のブロックの実行結果に対してメソッドが移譲される。
=end

class IrregularEval

  Object.methods.each{ |method|
    define_method(method){ |*args, &proc|
      method_missing(method, *args, &proc) } }

  def method_missing(method, *args, &block)
    irregular_eval_object.__send__(method, *args, &block) end end

class Lazy < IrregularEval

  def initialize
    @proc = Proc.new
    @obj = nil end

  def irregular_eval_object
    if @proc
      @obj = @proc.call
      @proc = nil end
    @obj end end

# 毎回評価
# Lazyの、呼び出しごとにブロックを評価するバージョン。
class EveryTime < IrregularEval

  def initialize
    @proc = Proc.new end

  def irregular_eval_object
    @proc.call end end

# 平行評価
# このインスタンスはすぐに別スレッドでブロックの評価が始まり、そのブロックの戻り値として振舞う。
# ただし、ブロックの処理が終わる前にこのオブジェクトを参照した場合、参照元のスレッドは値が返るまで
# ブロッキングされる
class Parallel < IrregularEval

  def initialize
    @proc = Thread.new(&Proc.new)
    @obj = nil end

  def irregular_eval_object
    if @proc
      @obj = @proc.value
      @proc = nil end
    @obj end end

# 遅延評価オブジェクトを作成する
def lazy(&proc)
  Lazy.new(&proc) end

# 毎回評価オブジェクトを作成する
def everytime(&proc)
  EveryTime.new(&proc) end

# 平行評価オブジェクトを作成する
def parallel(&proc)
  Parallel.new(&proc) end

