# -*- coding: utf-8 -*-

class Plugin
  module GUI; end end

require 'test/unit'
require File.expand_path(__dir__ + '/../../../lib/test_unit_extensions')
require File.expand_path(__dir__ + '/../cuscadable')
require File.expand_path(__dir__ + '/../../../utils')

class TC_PluginGUICuscadable < Test::Unit::TestCase

  def setup
    @klass = Class.new{
      include Plugin::GUI::Cuscadable
    }
  end

  must "can read name and slug" do
    cuscadable = @klass.instance(:slug, "name")
    assert_equal(:slug, cuscadable.slug)
    assert_equal("name", cuscadable.name)
  end

  must "cannot create class via new method" do # !> assigned but unused variable - instance
    assert_raise(NoMethodError){@klass.new(:slug, "name")}
  end

  must "can get next item" do
    first = @klass.instance(:first, "tab 1")
    second = @klass.instance(:second, "tab 2")
    third = @klass.instance(:third, "tab 3")
    assert_equal(true, first.next == second) # !> assigned but unused variable - instance
    assert_equal(true, second.next == third)
    assert_equal(true, third.next == first)
  end

  must "can get prev item" do
    first = @klass.instance(:first, "tab 1")
    second = @klass.instance(:second, "tab 2")
    third = @klass.instance(:third, "tab 3")
    assert_equal(true, first.prev == third)
    assert_equal(true, second.prev == first)
    assert_equal(true, third.prev == second)
  end

end
# >> Run options: 
# >> 
# >> # Running tests:
# >> 
# >> ....
# >> 
# >> Finished tests in 0.001069s, 3741.1988 tests/s, 8417.6974 assertions/s.
# >> 
# >> 4 tests, 9 assertions, 0 failures, 0 errors, 0 skips
