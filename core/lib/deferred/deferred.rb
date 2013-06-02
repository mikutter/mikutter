# -*- coding: utf-8 -*-

class Deferred
  include Deferredable

  def initialize(follow = nil)
    @follow = follow
    @backtrace = caller if Mopt.debug
  end

  alias :deferredable_cancel :cancel
  def cancel
    deferredable_cancel
    @follow.cancel if @follow.is_a? Deferredable end

  class << self
    # 実行中のDeferredを失敗させる。raiseと違って、Exception以外のオブジェクトをtrap()に渡すことができる。
    # Deferredのnextとtrapの中でだけ呼び出すことができる。
    # ==== Args
    # [value] trap()に渡す値
    # ==== Throw
    # :__deferredable_fail をthrowする
    def fail(value)
      throw(:__deferredable_fail, value) end

    # 複数のdeferredを引数に取って、それら全ての実行が終了したら、
    # その結果を引数の順番通りに格納したArrayを引数に呼ばれるDeferredを返す。
    # 引数のDeferredが一つでも失敗するとこのメソッドの返すDeferredも失敗する。
    # ==== Args
    # [defer] 終了を待つDeferredオブジェクト
    # [*follow] 他のDeferredオブジェクト
    # ==== Return
    # Deferred
    def when(defer = nil, *follow)
      return deferred{ [] } if defer.nil?
      defer.next{ |res|
        Deferred.when(*follow).next{ |follow_res|
          [res] + follow_res
        }
      }
    end

    # Kernel#systemを呼び出して、コマンドが成功たら成功するDeferredを返す。
    # 失敗した場合、trap{}ブロックには $? の値(Process::Status)か、例外が発生した場合それが渡される
    # ==== Args
    # [*args] Kernel#system の引数
    # ==== Return
    # Deferred
    def system(*args)
      promise = Deferred.new
      Thread.new{
        if Kernel.system(*args)
          promise.call(true)
        else
          promise.fail($?) end
      }.trap{ |e|
        promise.fail(e) }
      promise
    end
  end

end

class Thread
  include Deferredable

  alias _deferredable_trap initialize
  def initialize(*args, &proc)
    _deferredable_trap(*args){ |*args|
      begin
        result = proc.call(*args)
        self.call(result)
        result
      rescue Exception => e
        self.fail(e)
      end
    }
  end

  alias :deferredable_cancel :cancel
  def cancel
    deferredable_cancel
    kill end

end

module Enumerable
  # 遅延each。あとで実行されるし、あんまりループに時間がかかるようなら一旦ループを終了する
  def deach(&proc)
    iteratee = to_a
    iteratee = dup if equal?(iteratee)
    deferred{
      result = nil
      while not iteratee.empty?
        item = iteratee.shift
        proc.call(item)
        if Delayer.expire?
          break result = iteratee.deach(&proc) end end
      result }
  end
end

def deferred(&proc)
  Deferred.new.next(&proc) end
# ~> -:4: uninitialized constant Deferred::Deferredable (NameError)


