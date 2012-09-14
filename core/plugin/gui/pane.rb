# -*- coding: utf-8 -*-
# ペインインターフェイスを提供するクラス

require File.expand_path File.join(File.dirname(__FILE__), 'cuscadable')
require File.expand_path File.join(File.dirname(__FILE__), 'hierarchy_parent')
require File.expand_path File.join(File.dirname(__FILE__), 'hierarchy_child')

class Plugin::GUI::Pane

  include Plugin::GUI::Cuscadable
  include Plugin::GUI::HierarchyParent
  include Plugin::GUI::HierarchyChild

  # instanceから呼ばれる。勝手に作成しないこと
  def initialize(slug, name)
    Plugin::GUI::Window.add_default << self
    Plugin.call(:pane_created, self)
  end

end
