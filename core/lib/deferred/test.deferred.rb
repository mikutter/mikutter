# -*- coding: utf-8 -*-

$LOAD_PATH.push(File.expand_path(File.join(File.dirname($0), '../..')))

# class Delayer

#   @@chain = []

#   def initialize(&proc)
#     @@chain << proc
#   end
#  # !> discarding old deferred
#   def self.run
#     while cb = @@chain.shift
#       (Thread.list - [Thread.main]).each{ |t| t.join }
#       cb.call # !> method redefined; discarding old trap
#     end
#   end

# end

# require 'deferredable'
# require 'deferred'
# require 'test/unit'

require 'test/unit'
require 'utils'
miquire :core, 'delayer'
miquire :lib, 'deferred', 'test_unit_extensions'

class TC_Deferred < Test::Unit::TestCase # !> method redefined; discarding old fail
  def setup()
  end

  def wait_all_tasks
    while !Delayer.empty? or !(Thread.list - [Thread.current]).empty?
      Delayer.run
      (Thread.list - [Thread.current]).each &:join
    end
  end

  def test_serial_execute # !> method redefined; discarding old callback
    ans = 0
    Deferred.new.next{
      10
    }.next{ |x|
      ans = x + 2
    }
    wait_all_tasks
    assert_equal(12, ans)
  end

  def test_exception
    ans = 0
    Deferred.new.next{
      10
    }.next{
      raise 'mikutan peropero'
    }.next{ |x|
      ans = x + 2
    }.trap{ |e|
      ans = e
    }
    wait_all_tasks
    assert_kind_of(RuntimeError, ans)
    assert_equal("#<RuntimeError: mikutan peropero>", ans.inspect)
  end

  def test_thread
    ans = 0 # !> method redefined; discarding old _execute
    Thread.new{
      39
    }.next{ |x|
      ans = x # !> method redefined; discarding old _post
    }
    wait_all_tasks
    assert_equal(39, ans)
  end

  def test_thread_error
    ans = 0
    Thread.new{
      raise
    }.next{ |x|
      ans = x
    }.trap{ |x|
      ans = x
    }
    wait_all_tasks
    assert_kind_of(RuntimeError, ans)
  end

  def test_thread_error_receive
    ans = 0
    deferred{
      Thread.new{
        1
      }.next{ |x|
        Thread.new{
          raise
        }.next{ |x|
          ans = x
        }
      }
    }.trap{ |x|
      ans = x
    }
    wait_all_tasks
    assert_kind_of(RuntimeError, ans)
  end

  def test_recursive
    trace = []
    deferred{
      trace << 1
    }.next{ |x|
      trace << 2
      deferred{
        trace << 3
      }.next{
        Thread.new{
          trace << 4
        }.next{
          trace << 5
          raise
        }.trap{
          trace << 6
        }
      }.trap{
        trace << 7
      }
    }
    trace << 8
    wait_all_tasks
    assert_equal([8, 1, 2, 3, 4, 5, 6], trace)
  # rescue SystemStackError => e
  #   puts e.backtrace
  #   raise e
  end

  def test_lator
    a = []
    d = deferred{ a << 1 }
    wait_all_tasks
    d.next{ a << 2 }.next{ a << 3 }
    wait_all_tasks
    assert_equal([1, 2, 3], a)
  end

  def test_when
    result = nil
    Deferred.when(deferred{ 1 }, deferred{ 2 }, deferred{ 3 }).next{ |res|
      result = res
    }
    wait_all_tasks
    assert_equal [1, 2, 3], result
  end

  # def test_aeach
  #   a = 0
  #   (1..1000000).aeach{
  #     Time.new
  #     a += 1
  #   }
  #   Delayer.run
  #   assert_equal(1000000, a)
  # end

end


# >> Loaded suite -
# >> Started
# >> F.F....
# >> Finished in 0.210219 seconds.
# >> 
# >>   1) Failure:
# >> test_aeach(TC_Deferred) [-:121]:
# >> <1000000> expected but was
# >> <0>.
# >> 
# >>   2) Failure:
# >> test_lator(TC_Deferred) [-:111]:
# >> <[1, 2, 3]> expected but was
# >> <[1]>.
# >> 
# >> 7 tests, 8 assertions, 2 failures, 0 errors
