# -*- coding: utf-8 -*-
# ペインインターフェイスを提供するクラス

require File.expand_path File.join(File.dirname(__FILE__), 'cuscadable')
require File.expand_path File.join(File.dirname(__FILE__), 'hierarchy_parent')
require File.expand_path File.join(File.dirname(__FILE__), 'hierarchy_child')
require File.expand_path File.join(File.dirname(__FILE__), 'window')

class Plugin::GUI::Pane

  include Plugin::GUI::Cuscadable
  include Plugin::GUI::HierarchyParent
  include Plugin::GUI::HierarchyChild

  # instanceから呼ばれる。勝手に作成しないこと
  def initialize(slug, name)
    super
    # Plugin::GUI::Window.add_default << self
    Plugin.call(:pane_created, self)
  end

  alias __set_parent_pane__ set_parent
  def set_parent(parent)
    Plugin.call(:gui_pane_join_window, self, parent)
    __set_parent_pane__(parent)
  end

  def self.active
    instance(:default, "デフォルト")
  end

end
