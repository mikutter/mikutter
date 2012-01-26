# -*- coding: utf-8 -*-

class Deferred
  include Deferredable

  def initialize(follow = nil)
    @follow = follow
  end

  class << self
    def when(defer = nil, *follow)
      return deferred{ [] } if defer.nil?
      defer.next{ |res|
        Deferred.when(*follow).next{ |follow_res|
          [res] + follow_res
        }
      }
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
end

module Enumerable
  def aeach(&proc)
    start_time = 0
    ary = to_a
    limit = ary.size
    index = 0
    peace = lambda{
      start_time = Time.new.to_f
      while(index >= limit)
        if (Time.new.to_f - start_time) >= 0.01
          peace.call
          break deferred{ peace.call }
        else
          result = proc.call(ary[index])
          index += 1
          result end end }
    deferred{ peace.call }
  end
end

def deferred(&proc)
  Deferred.new.next(&proc) end
# ~> -:4: uninitialized constant Deferred::Deferredable (NameError)
