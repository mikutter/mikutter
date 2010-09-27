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

# 遅延評価オブジェクトを作成する
def lazy(&proc)
  Lazy.new(&proc) end
