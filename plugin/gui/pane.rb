# -*- coding: utf-8 -*-
# ペインインターフェイスを提供するクラス

require_relative 'cuscadable'
require_relative 'hierarchy_parent'
require_relative 'hierarchy_child'
require_relative 'window'
require_relative 'widget'

class Plugin::GUI::Pane

  include Plugin::GUI::Cuscadable
  include Plugin::GUI::HierarchyChild
  include Plugin::GUI::HierarchyParent
  include Plugin::GUI::Widget

  role :pane

  set_parent_event :gui_pane_join_window

  # instanceから呼ばれる。勝手に作成しないこと
  def initialize(*args)
    super
    @@default ||= self
    Plugin.call(:pane_created, self)
  end

  def active!(just_this=true, by_toolkit=false)
    @@default = self
    super end

  def self.active
    @@default ||= instance(:default, "デフォルト")
  end

  def add_child(child, index=children.size)
    result = super(child, index)
    if children[index+1] == @active_child
      Delayer.new{ child.active! } end
    result end

end
