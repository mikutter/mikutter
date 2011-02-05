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

  def irregulareval?
    true end

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

# メソッド呼び出しを遅延する。
# 呼び出すメソッドのオブジェクト部分をこのオブジェクトに置き換えると、そのメソッド呼び出しが
# 記録され、MethodCallDelayer#call が呼ばれたときに、callの引数をオブジェクトとして評価が開始される。
#   f = function.map{ |x| x + 1 }.join(', ')
#   f.call([1, 2, 3]) # => "2, 3, 4"
class MethodCallDelayer < IrregularEval

  def initialize
    @callstack = lambda{ |x| x } end

  def method_missing(*args, &block)
    callstack = @callstack
    @callstack = lambda{ |x|
      callstack.call(x).__send__(*args, &block) }
    self end

  # _obj_ をselfとして評価を開始する。
  def call(obj)
    to_proc.call(obj) end

  # Procオブジェクトにして返す。
  # ブロック引数としてこのオブジェクトを渡した場合に内部で呼ばれる。
  def to_proc
    @callstack end end

# 遅延評価オブジェクトを作成する。ブロックを取って呼ばれた場合は Lazy のインスタンスを、
# 何も取らずに読んだ場合は MethodCallDelayer のインスタンスを返す。
def lazy(&proc)
  if proc
    Lazy.new(&proc)
  else
    MethodCallDelayer.new end end

# 毎回評価オブジェクトを作成する
def everytime(&proc)
  EveryTime.new(&proc) end

# 平行評価オブジェクトを作成する
def parallel(&proc)
  Parallel.new(&proc) end

# 値が真であるならtrueを返す。遅延評価オブジェクトでも正確に判断することができる。
def bool(val)
  not(val.nil? or val.is_a?(FalseClass)) end
