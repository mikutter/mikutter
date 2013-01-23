# -*- coding: utf-8 -*-

require 'test/unit'
require 'rubygems'
require 'mocha'
require File.expand_path(File.dirname(__FILE__) + '/../helper')

Dir.chdir(File.expand_path(File.dirname(__FILE__) + '/../core'))
$LOAD_PATH.push '.'
require 'utils'

miquire :lib, 'test_unit_extensions'
miquire :core, 'event_listener'

class TC_EventListener < Test::Unit::TestCase
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
    Event[:increase].call(1)
    Delayer.run while not Delayer.empty?
    assert_equal(1, value)
    assert_equal(-1, d_value)

    Event[:decrease].call(2)
    Event[:increase].call(3)
    Delayer.run while not Delayer.empty?
    assert_equal(2, value)
    assert_equal(-2, d_value)

    assert_equal(4, sum)
    assert_equal(2, d_sum)
  end

  must "event stop" do
    value = 0
    EventListener.new(Event[:stop_test]) { |v, &stop|
      stop.call if (v % 2) == 0
    }
    EventListener.new(Event[:stop_test]) { |v|
      value += v
    }
    Event[:stop_test].call(1)
    Event[:stop_test].call(2)
    Event[:stop_test].call(3)
    Event[:stop_test].call(4)
    Delayer.run while not Delayer.empty?
    assert_equal(4, value)
  end
end

