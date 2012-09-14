# -*- coding: utf-8 -*-
# タブのインターフェイスを提供するクラス

require File.expand_path File.join(File.dirname(__FILE__), 'pane')
require File.expand_path File.join(File.dirname(__FILE__), 'cuscadable')
require File.expand_path File.join(File.dirname(__FILE__), 'hierarchy_child')
require File.expand_path File.join(File.dirname(__FILE__), 'hierarchy_parent')
require File.expand_path File.join(File.dirname(__FILE__), 'widget')

class Plugin::GUI::Tab

  include Plugin::GUI::Cuscadable
  include Plugin::GUI::HierarchyChild
  include Plugin::GUI::HierarchyParent
  include Plugin::GUI::Widget

  role :tab

  attr_reader :icon

  # instanceから呼ばれる。勝手に作成しないこと
  def initialize(slug, name)
    super
    position = Plugin::GUI.get_tab_order(slug)
    if position
      p position
      window_slug, pane_slug, order = position
      Plugin::GUI::Pane.instance(pane_slug) << self
    else
      Plugin::GUI::Pane.add_default << self
    end
    Plugin.call(:tab_created, self)
  end

  alias __set_parent_tab__ set_parent
  def set_parent(pane)
    Plugin.call(:gui_tab_join_pane, self, pane)
    __set_parent_tab__(pane)
  end

  # タイムラインを作成してこの中に入れる
  # ==== Args
  # [slug] タイムラインスラッグ
  # [&proc] 処理
  # ==== Return
  # self
  def timeline(slug, &proc)
    timeline = Plugin::GUI::Timeline.instance(slug)
    self << timeline
    timeline.instance_eval &proc if proc
    timeline
  end

  def set_icon(new)
    if @icon != new
      @icon = new
      Plugin.call(:gui_tab_change_icon, self) end
    self end

end
