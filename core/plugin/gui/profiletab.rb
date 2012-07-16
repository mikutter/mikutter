# -*- coding: utf-8 -*-

require File.expand_path File.join(File.dirname(__FILE__), 'cuscadable')
require File.expand_path File.join(File.dirname(__FILE__), 'hierarchy_parent')
require File.expand_path File.join(File.dirname(__FILE__), 'hierarchy_child')
require File.expand_path File.join(File.dirname(__FILE__), 'window')
require File.expand_path File.join(File.dirname(__FILE__), 'tablike')
require File.expand_path File.join(File.dirname(__FILE__), 'widget')

class Plugin::GUI::ProfileTab
  include Plugin::GUI::Cuscadable
  include Plugin::GUI::HierarchyChild
  include Plugin::GUI::HierarchyParent
  include Plugin::GUI::Widget
  include Plugin::GUI::TabLike

  role :profiletab

  attr_reader :user

  def initialize(slug, name)
    super
    Plugin.call(:profiletab_created, self)
  end

  alias __set_parent_profiletab__ set_parent
  def set_parent(pane)
    Plugin.call(:gui_profiletab_join_profile, self, pane)
    __set_parent_profiletab__(pane)
  end

end
