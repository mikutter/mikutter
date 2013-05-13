# -*- coding: utf-8 -*-

require 'test/unit'
require 'rubygems'
require 'mocha'
require File.expand_path(File.dirname(__FILE__) + '/../helper')

Dir.chdir(File.expand_path(File.dirname(__FILE__) + '/../core'))
$LOAD_PATH.push '.'
require 'utils'

miquire :lib, 'test_unit_extensions'
miquire :core, 'event_filter', 'event_listener'

class TC_EventFilter < Test::Unit::TestCase
  def setup
    Event.clear!
  end

  must "start listening" do
    value = d_value = sum = d_sum = 0
    increase = EventListener.new(Event[:increase]) { |v|
      value += v
      d_value -= v
      sum += v
    }
    decrease = EventListener.new(Event[:decrease]) { |v|
      value -= v
      d_value += v
      d_sum += v
    }
    EventFilter.new(Event[:increase]){ |v| [v * 2] }
    Event[:increase].call(1)
    Delayer.run while not Delayer.empty?
    assert_equal(2, value)
    assert_equal(-2, d_value)

    Event[:decrease].call(2)
    Event[:increase].call(3)
    Delayer.run while not Delayer.empty?
    assert_equal(6, value)
    assert_equal(-6, d_value)

    assert_equal(8, sum)
    assert_equal(2, d_sum)
  end

  must "cancel" do
    EventFilter.new(Event[:increase]){ |v| [v * 2] }
    result = Event[:increase].filtering(1)
    assert_equal([2], result)

    EventFilter.new(Event[:increase]){ |v| [v * 2] }
    result = Event[:increase].filtering(1)
    assert_equal([4], result)

    e1 = EventFilter.new(Event[:increase]){ |v| EventFilter.cancel! }
    result = Event[:increase].filtering(1)
    assert_equal(false, result)

    e1.detach

    EventFilter.new(Event[:increase]){ |v, &cont| cont.call([v*3]) }
    result = Event[:increase].filtering(1)
    assert_equal([12], result)
  end
end

