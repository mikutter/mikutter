# -*- coding: utf-8 -*-
# ペインインターフェイスを提供するクラス

require File.expand_path File.join(File.dirname(__FILE__), 'cuscadable')
require File.expand_path File.join(File.dirname(__FILE__), 'hierarchy_parent')
require File.expand_path File.join(File.dirname(__FILE__), 'hierarchy_child')
require File.expand_path File.join(File.dirname(__FILE__), 'window')
require File.expand_path File.join(File.dirname(__FILE__), 'widget')

class Plugin::GUI::Pane

  include Plugin::GUI::Cuscadable
  include Plugin::GUI::HierarchyParent
  include Plugin::GUI::HierarchyChild
  include Plugin::GUI::Widget

  role :pane

  set_parent_event :gui_pane_join_window

  # instanceから呼ばれる。勝手に作成しないこと
  def initialize(*args)
    super
    @@default ||= self
    Plugin.call(:pane_created, self)
  end

  def active!(just_this=true)
    @@default = self
    super end

  def self.active
    @@default ||= instance(:default, "デフォルト")
  end

end
