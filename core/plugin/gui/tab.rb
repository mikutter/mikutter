# -*- coding: utf-8 -*-
# タブのインターフェイスを提供するクラス

require File.expand_path File.join(File.dirname(__FILE__), 'cuscadable')
require File.expand_path File.join(File.dirname(__FILE__), 'hierarchy_child')

class Plugin::GUI::Tab

  include Plugin::GUI::Cuscadable
  include Plugin::GUI::HierarchyChild

  # instanceから呼ばれる。勝手に作成しないこと
  def initialize(slug, name)
    Plugin::GUI::Pane.add_default << self
    Plugin.call(:tab_created, self)
  end

end
