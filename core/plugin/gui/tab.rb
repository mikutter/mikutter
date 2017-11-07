# -*- coding: utf-8 -*-
# タブのインターフェイスを提供するクラス

require_relative 'pane'
require_relative 'cuscadable'
require_relative 'hierarchy_child'
require_relative 'hierarchy_parent'
require_relative 'tablike'
require_relative 'widget'
require_relative 'tab_toolbar'

class Plugin::GUI::Tab

  include Plugin::GUI::Cuscadable
  include Plugin::GUI::HierarchyChild
  include Plugin::GUI::HierarchyParent
  include Plugin::GUI::Widget
  include Plugin::GUI::TabLike

  role :tab

  set_parent_event :gui_tab_join_pane

  attr_reader :tab_toolbar

  # instanceから呼ばれる。勝手に作成しないこと
  def initialize(*args)
    super
    @temporary_tab = false
    position = Plugin::GUI.get_tab_order(slug)
    if position
      _, pane_slug, order = position
      pane = Plugin::GUI::Pane.instance(pane_slug)
      index = where_should_insert_it(slug, pane.children.map(&:slug), order)
      pane.add_child(self, index)
    else
      Plugin::GUI::Pane.add_default << self
    end
    @tab_toolbar = Plugin::GUI::TabToolbar.instance
    Plugin.call(:tab_created, self)
    shrink
    add_child(@tab_toolbar)
    expand
  end

  # このタブが一時的なタブであることを宣言する。
  # タブの並び順に記録されないようになり、次回起動時にタブが生成されない。
  # ==== Return
  # self
  def temporary_tab(value=true)
    @temporary_tab = value end

  # このタブが一時的なタブかどうかを返す
  # ==== Return
  # self
  def temporary_tab?
    @temporary_tab end
end
