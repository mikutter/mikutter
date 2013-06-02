# -*- coding: utf-8 -*-

$LOAD_PATH.push(File.expand_path(File.join(File.dirname($0), '../..')))

# class Delayer

#   @@chain = []

#   def initialize(&proc)
#     @@chain << proc
#   end
# 
#   def self.run
#     while cb = @@chain.shift
#       (Thread.list - [Thread.main]).each{ |t| t.join }
#       cb.call
#     end
#   end

# end

# require 'deferredable'
# require 'deferred'
# require 'test/unit'

require 'test/unit'
require 'utils'
miquire :lib, 'delayer', 'deferred', 'test_unit_extensions'

class TC_Deferred < Test::Unit::TestCase
  def setup()
  end

  def wait_all_tasks
    while !Delayer.empty? or !(Thread.list - [Thread.current]).empty?
      Delayer.run
      (Thread.list - [Thread.current]).each &:join # !> `&' interpreted as argument prefix
    end
  end

  def test_serial_execute
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
    assert_kind_of(RuntimeError, ans) # !> shadowing outer local variable - bt
    assert_equal("#<RuntimeError: mikutan peropero>", ans.inspect)
  end

  def test_fail # !> shadowing outer local variable - args
    ans = 0
    Deferred.new.next{
      10
    }.next{
      Deferred.fail 'mikutan peropero'
    }.next{ |x|
      ans = x + 2
    }.trap{ |e|
      ans = e # !> instance variable @next not initialized
    }
    wait_all_tasks
    assert_kind_of(String, ans)
    assert_equal("mikutan peropero", ans)
  end

  def test_thread
    ans = 0
    Thread.new{
      39
    }.next{ |x|
      x + 1
    }.next{ |x|
      ans = x
    }
    wait_all_tasks
    assert_equal(40, ans)
  end

  def test_thread_error
    ans = 0
    Thread.new{
      raise
    }.next{ |x|
      ans = x
    }.trap{ |x|
      ans = x # !> ambiguous first argument; put parentheses or even spaces
    }
    wait_all_tasks
    assert_kind_of(RuntimeError, ans)
  end

  def test_thread_error_receive # !> `&' interpreted as argument prefix
    ans = 0
    deferred{
      Thread.new{
        1
      }.next{ |x|
        Thread.new{
          raise
        }.next{ |x| # !> shadowing outer local variable - x
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

  def test_cancel
    ans = 0
    Thread.new{
      sleep(10)
      39
    }.next{ |x|
      ans = x
    }.cancel
    wait_all_tasks
    assert_equal(0, ans)
  end

  def test_deach
    a = 0
    (1..100000).deach{
      a += 1
    }
    wait_all_tasks
    assert_equal(100000, a)
  end

  def test_system_success
    result = nil
    Deferred.system("ruby", "-e", "exit").next{ |v| result = v }
    wait_all_tasks
    assert_equal(true, result) # !> `&' interpreted as argument prefix
  end

  def test_system_fail
    result = 0
    Deferred.system("ruby", "-e", "abort").trap{ |v| result = v }
    wait_all_tasks
    assert_kind_of(Process::Status, result)
    assert_equal(256, result.to_i)
  end

end

# >> Run options: 
# >> 
# >> # Running tests:
# >> 
# >> .............
# >> 
# >> Finished tests in 0.296070s, 43.9085 tests/s, 54.0412 assertions/s.
# >> 
# >> 13 tests, 16 assertions, 0 failures, 0 errors, 0 skips
