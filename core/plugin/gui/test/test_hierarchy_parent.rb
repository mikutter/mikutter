# -*- coding: utf-8 -*-

class Plugin
  module GUI; end end

require 'test/unit'
require File.expand_path(File.dirname(__FILE__) + '/../../../lib/test_unit_extensions')
require File.expand_path(File.dirname(__FILE__) + '/../hierarchy_parent')
require File.expand_path(File.dirname(__FILE__) + '/../hierarchy_child')
require File.expand_path(File.dirname(__FILE__) + '/../../../utils')

class TC_PluginGUIHierarchyParent < Test::Unit::TestCase

  def setup
    @kparent = Class.new{
      include Plugin::GUI::HierarchyParent
      class << self # !> instance variable @parent_class not initialized
        attr_accessor :active end }

    @kchild = Class.new{
      include Plugin::GUI::HierarchyParent
      include Plugin::GUI::HierarchyChild }
    @kchild.set_parent_class @kparent

    @kgrandchild = Class.new{
      include Plugin::GUI::HierarchyChild }
    @kgrandchild.set_parent_class @kchild
  end

  must "set child" do
    parent = @kparent.new
    child = @kchild.new
    parent << child
    assert_equal(true, parent.children.first == child)
    assert_equal(true, child.parent == parent)
  end

  must "child activation" do
    parent = @kparent.new
    @kparent.active = parent
    children = [@kchild.new, @kchild.new]
    grandchildren = [@kgrandchild.new]
    parent << children[0] << children[1]
    children[0] << grandchildren[0]
    assert_equal(children[0], parent.active_child)
    assert_equal([children[0], grandchildren[0]], parent.active_chain)
    assert_equal(grandchildren[0], parent.active_class_of(@kgrandchild))
    assert_equal(grandchildren[0], @kgrandchild.active)
  end

end
# >> Run options: 
# >> 
# >> # Running tests:
# >> 
# >> ..
# >> 
# >> Finished tests in 0.000899s, 2224.5753 tests/s, 6673.7260 assertions/s.
# >> 
# >> 2 tests, 6 assertions, 0 failures, 0 errors, 0 skips
