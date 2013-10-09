# -*- coding: utf-8 -*-

require File.expand_path File.join(File.dirname(__FILE__), 'pane')
require File.expand_path File.join(File.dirname(__FILE__), 'cuscadable')
require File.expand_path File.join(File.dirname(__FILE__), 'hierarchy_child')
require File.expand_path File.join(File.dirname(__FILE__), 'tab')
require File.expand_path File.join(File.dirname(__FILE__), 'widget')

# タブにコマンドを表示するウィジェット
class Plugin::GUI::TabToolbar

  include Plugin::GUI::Cuscadable
  include Plugin::GUI::HierarchyChild
  include Plugin::GUI::Widget

  role :tab_toolbar

  set_parent_event :gui_tab_toolbar_join_tab

  def initialize(*args)
    super
    Plugin.call(:tab_toolbar_created, self)
  end

  def rewind
    Plugin.call(:tab_toolbar_rewind, self)
  end

end
