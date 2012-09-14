# -*- coding: utf-8 -*-

class Plugin
  module GUI; end end

require 'test/unit'
require File.expand_path(File.dirname(__FILE__) + '/../../../lib/test_unit_extensions')
require File.expand_path(File.dirname(__FILE__) + '/../hierarchy_parent')
require File.expand_path(File.dirname(__FILE__) + '/../hierarchy_child')

class TC_PluginGUIHierarchyParent < Test::Unit::TestCase

  def setup
    @kparent = Class.new{
      include Plugin::GUI::HierarchyParent
      class << self
        attr_accessor :active end
    }
    @kchild = Class.new{
      include Plugin::GUI::HierarchyChild
    }
  end

  must "set child" do
    parent = @kparent.new
    child = @kchild.new
    parent << child
    assert_equal(true, parent.children.first == child)
    assert_equal(true, child.parent == parent)
  end

end
# >> Run options: 
# >> 
# >> # Running tests:
# >> 
# >> .
# >> 
# >> Finished tests in 0.000484s, 2068.2438 tests/s, 4136.4875 assertions/s.
# >> 
# >> 1 tests, 2 assertions, 0 failures, 0 errors, 0 skips
