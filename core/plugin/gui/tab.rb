# -*- coding: utf-8 -*-
# タブのインターフェイスを提供するクラス

require File.expand_path File.join(File.dirname(__FILE__), 'pane')
require File.expand_path File.join(File.dirname(__FILE__), 'cuscadable')
require File.expand_path File.join(File.dirname(__FILE__), 'hierarchy_child')
require File.expand_path File.join(File.dirname(__FILE__), 'hierarchy_parent')
require File.expand_path File.join(File.dirname(__FILE__), 'tablike')
require File.expand_path File.join(File.dirname(__FILE__), 'widget')

class Plugin::GUI::Tab

  include Plugin::GUI::Cuscadable
  include Plugin::GUI::HierarchyChild
  include Plugin::GUI::HierarchyParent
  include Plugin::GUI::Widget
  include Plugin::GUI::TabLike

  role :tab

  set_parent_event :gui_tab_join_pane

  # instanceから呼ばれる。勝手に作成しないこと
  def initialize(*args)
    super
    position = Plugin::GUI.get_tab_order(slug)
    if position
      window_slug, pane_slug, order = position
      pane = Plugin::GUI::Pane.instance(pane_slug)
      index = where_should_insert_it(slug, pane.children.map(&:slug), order)
      notice "tab initialize #{slug} #{position.inspect} #{index}"
      pane.add_child(self, index)
    else
      Plugin::GUI::Pane.add_default << self
    end
    Plugin.call(:tab_created, self)
  end
end
