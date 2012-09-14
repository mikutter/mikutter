# -*- coding: utf-8 -*-

require File.expand_path File.join(File.dirname(__FILE__), 'pane')
require File.expand_path File.join(File.dirname(__FILE__), 'cuscadable')
require File.expand_path File.join(File.dirname(__FILE__), 'hierarchy_child')
require File.expand_path File.join(File.dirname(__FILE__), 'tab')
require File.expand_path File.join(File.dirname(__FILE__), 'widget')

class Plugin::GUI::TabChildWidget

  include Plugin::GUI::Cuscadable
  include Plugin::GUI::HierarchyChild
  include Plugin::GUI::Widget
  
  role :tabchildwidget

  def initialize(*args)
    super
    Plugin.call(:tabchildwidget_created, self)
  end

  alias __set_parent_tabchildwidget__ set_parent
  def set_parent(tab)
    Plugin.call(:gui_tabchildwidget_join_tab, self, tab)
    __set_parent_tabchildwidget__(tab)
  end

  def <<(messages)
    Plugin.call(:gui_tabchildwidget_add_messages, self, messages)
  end

end
