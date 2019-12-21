# -*- coding: utf-8 -*-

require_relative 'pane'
require_relative 'cuscadable'
require_relative 'hierarchy_child'
require_relative 'tab'
require_relative 'widget'

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
