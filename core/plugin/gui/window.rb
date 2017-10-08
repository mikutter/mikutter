# -*- coding: utf-8 -*-
# ウィンドウインターフェイスを提供するクラス

require_relative 'cuscadable'
require_relative 'hierarchy_parent'
require_relative 'widget'

class Plugin::GUI::Window

  include Plugin::GUI::Cuscadable
  include Plugin::GUI::HierarchyParent
  include Plugin::GUI::Widget

  role :window

  attr_reader :icon

  # instanceから呼ばれる。勝手に作成しないこと
  def initialize(*args)
    super
    @@active ||= self
    Plugin.call(:window_created, self)
  end

  # self がアクティブになったことを報告する
  def active!(just_this=true, by_toolkit=false)
    @@active = self
  end

  def self.active
    @@active ||= instance(:default, _("デフォルト"))
  end

  def set_icon(icon)
    case icon
    when Retriever::Model
      @icon = icon
    when String
      @icon = Retriever::Model(:photo)[icon]
    else
      raise RuntimeError, "Unexpected class `#{icon.class}'."
    end
    Plugin.call(:gui_window_change_icon, self, icon)
  end

end
