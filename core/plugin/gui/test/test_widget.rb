# -*- coding: utf-8 -*-

class Plugin
  module GUI; end end

require 'test/unit'
require File.expand_path(File.dirname(__FILE__) + '/../../../lib/test_unit_extensions')
require File.expand_path(File.dirname(__FILE__) + '/../widget')
require File.expand_path(File.dirname(__FILE__) + '/../hierarchy_parent')
require File.expand_path(File.dirname(__FILE__) + '/../hierarchy_child')
require File.expand_path(File.dirname(__FILE__) + '/../../../utils')

class TC_PluginGUIWidget < Test::Unit::TestCase

  def setup
    @kparent = Class.new{
      include Plugin::GUI::HierarchyParent
      include Plugin::GUI::Widget
      role :kparent
      attr_accessor :slug
      class << self
        attr_accessor :active end }

    @kchild = Class.new{
      include Plugin::GUI::HierarchyParent
      include Plugin::GUI::HierarchyChild
      include Plugin::GUI::Widget
      role :kchild }
    @kchild.set_parent_class @kparent
  end

  must "get role" do
    assert_equal(:kparent, @kparent.role)
    assert_equal(:kchild, @kchild.role)
  end

  must "role ancestor" do
    assert_equal(@kparent, @kchild.find_role_ancestor(:kparent))
    assert_equal(@kchild, @kchild.find_role_ancestor(:kchild))
    assert_equal(@kparent, @kparent.find_role_ancestor(:kparent))
    assert_nil(@kparent.find_role_ancestor(:kchild))
  end

end
