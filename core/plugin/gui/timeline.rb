# -*- coding: utf-8 -*-

require File.expand_path File.join(File.dirname(__FILE__), 'pane')
require File.expand_path File.join(File.dirname(__FILE__), 'cuscadable')
require File.expand_path File.join(File.dirname(__FILE__), 'hierarchy_child')
require File.expand_path File.join(File.dirname(__FILE__), 'tab')
require File.expand_path File.join(File.dirname(__FILE__), 'widget')

class Plugin::GUI::Timeline

  include Plugin::GUI::Cuscadable
  include Plugin::GUI::HierarchyChild
  include Plugin::GUI::Widget

  role :timeline

  def initialize(slug, name)
    super
    Plugin.call(:timeline_created, self)
  end

  alias __set_parent_timeline__ set_parent
  def set_parent(tab)
    Plugin.call(:gui_timeline_join_tab, self, tab)
    __set_parent_timeline__(tab)
  end

  def <<(messages)
    Plugin.call(:gui_timeline_add_messages, self, messages)
  end

  # 選択されているMessageを返す
  # ==== Return
  # 選択されているMessage
  def selected_messages
    Plugin.call(:gui_timeline_selected_messages, self, [])
  end

end
