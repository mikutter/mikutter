# -*- coding: utf-8 -*-

require File.expand_path(File.dirname(__FILE__) + '/../../helper')

Dir.chdir(File.expand_path(File.dirname(__FILE__) + '/../../core'))
$LOAD_PATH.push '.'
require 'utils'

miquire :lib, 'test_unit_extensions'
miquire :lib, 'deferred'

class TC_Deferred < Test::Unit::TestCase
  def setup
  end

  def wait
    while !Delayer.empty? || !(Thread.list - [Thread.current]).empty?
      Delayer.run
      (Thread.list - [Thread.current]).each &:join
    end
  end

  must "execute serially" do
    ans = 0
    Deferred.new.next{
      10
    }.next{ |x|
      ans = x + 2
    }
    wait
    assert_equal(12, ans)
  end

  must "trap exception" do
    ans = 0
    exception = Exception.new
    Deferred.new.next{
      10
    }.next{
      raise exception
    }.next{ |x|
      ans = x + 2
    }.trap{ |e|
      ans = e
    }
    wait
    assert_equal(exception, ans)
  end

  must "fail manually" do
    ans = 0
    Deferred.new.next{
      10
    }.next{
      Deferred.fail "mikutan peropero"
    }.next{ |x|
      ans = x + 2
    }.trap{ |e|
      ans = e
    }
    wait
    assert_equal("mikutan peropero", ans)
  end

  must "thread be deferredable" do
    ans = 0
    Thread.new{
      39
    }.next{ |x|
      x + 1
    }.next{ |x|
      ans = x
    }
    wait
    assert_equal(ans, 40)
  end

  must "handle exception" do
    ans = 0
    exception = Exception.new
    th = nil
    Thread.new{
      raise exception
    }.tap{ |t|
      th = t
    }.next{ |x|
      ans = x
    }.trap{ |x|
      ans = x
    }
    assert_raise(exception){ th.join }
    wait
    assert_equal(exception, ans)
  end

  must "execute in deterministic order" do
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
        trace << nil
      }
    }
    trace << 0
    wait
    assert_equal([0, 1, 2, 3, 4, 5, 6], trace)
  end

  must "extend chain later" do
    a = []
    d = deferred{ a << 1 }
    wait
    d.next{ a << 2 }.next{ a << 3 }
    wait
    assert_equal([1, 2, 3], a)
  end

  must "trap error later" do
    ans = nil
    exception = Exception.new
    d = deferred{
      raise exception
    }
    wait
    d.trap{ |e|
      ans = e
    }
    assert_equal(exception, ans)
  end

  must "trap error later (thread)" do
    ans = nil
    exception = Exception.new
    th = Thread.new{
      raise exception
    }
    assert_raise(exception){ th.join }
    th.trap{ |e|
      ans = e
    }
    assert_equal(exception, ans)
  end

  must "control evaluation order" do
    ans = nil
    Deferred.when(deferred{ 1 }, deferred{ 2 }, deferred{ 3 }).next{ |res|
      ans = res
    }
    wait
    assert_equal([1, 2, 3], ans)
  end

  must "cancel execution" do
    ans = 0
    Thread.new{
      sleep(10)
      39
    }.next{ |x|
      ans = x
    }.cancel
    wait
    assert_equal(0, ans)
  end

  must "deach work" do
    ans = 0
    (1..100000).deach{
      ans += 1
    }
    wait
    assert_equal(100000, ans)
  end

  must "give true when #system success" do
    ans = 0
    Deferred.system("ruby", "-e", "exit").next{ |v| ans = v }
    wait
    assert_equal(true, ans)
  end

  must "give error with exit code when #system fail" do
    ans = 0
    Deferred.system("ruby", "-e", "abort").trap{ |v| ans = v }
    wait
    assert_kind_of(Process::Status, ans)
    assert_equal(256, ans.to_i)
  end
end
