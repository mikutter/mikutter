# -*- coding: utf-8 -*-

require 'test/unit'
require 'rubygems'
require 'mocha'
require File.expand_path(File.dirname(__FILE__) + '/../helper')

Dir.chdir(File.expand_path(File.dirname(__FILE__) + '/../core'))
$LOAD_PATH.push '.'
require 'utils'

miquire :lib, 'test_unit_extensions'
miquire :core, 'event'

class TC_Event < Test::Unit::TestCase
  def setup
    Event.clear!
  end

  must "register" do
    assert_instance_of Event, Event[:register_test]
    assert Event[:register_test].eql? Event[:register_test]
    assert_raise(ArgumentError) {
      Event["fail"] }
  end

  must "priority" do
    assert_kind_of Fixnum, Event[:prio1].priority
    Event[:prio1].options[:priority] = Delayer::UI_RESPONSE
    assert_equal Delayer::UI_RESPONSE, Event[:prio1].priority
  end
end

