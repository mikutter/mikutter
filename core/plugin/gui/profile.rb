# -*- coding: utf-8 -*-
# プロフィールタブを提供するクラス

require File.expand_path File.join(File.dirname(__FILE__), 'cuscadable')
require File.expand_path File.join(File.dirname(__FILE__), 'hierarchy_parent')
require File.expand_path File.join(File.dirname(__FILE__), 'hierarchy_child')
require File.expand_path File.join(File.dirname(__FILE__), 'window')
require File.expand_path File.join(File.dirname(__FILE__), 'widget')

class Plugin::GUI::Profile

  include Plugin::GUI::Cuscadable
  include Plugin::GUI::HierarchyParent
  include Plugin::GUI::HierarchyChild
  include Plugin::GUI::Widget

  role :profile

  # instanceから呼ばれる。勝手に作成しないこと
  def initialize(slug, name)
    super
    # Plugin::GUI::Window.add_default << self
    Plugin.call(:profile_created, self)
  end

  alias __set_parent_pane__ set_parent
  def set_parent(parent)
    Plugin.call(:gui_profile_join_tab, self, parent)
    __set_parent_pane__(parent)
  end

end
