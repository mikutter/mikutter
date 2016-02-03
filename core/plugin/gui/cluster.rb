# -*- coding: utf-8 -*-
# プロフィールタブを提供するクラス

require File.expand_path File.join(File.dirname(__FILE__), 'cuscadable')
require File.expand_path File.join(File.dirname(__FILE__), 'hierarchy_parent')
require File.expand_path File.join(File.dirname(__FILE__), 'hierarchy_child')
require File.expand_path File.join(File.dirname(__FILE__), 'window')
require File.expand_path File.join(File.dirname(__FILE__), 'widget')

class Plugin::GUI::Cluster

  include Plugin::GUI::Cuscadable
  include Plugin::GUI::HierarchyChild
  include Plugin::GUI::HierarchyParent
  include Plugin::GUI::Widget

  role :cluster

  set_parent_event :gui_profile_join_tab

  # instanceから呼ばれる。勝手に作成しないこと
  def initialize(*args)
    super
    Plugin.call(:cluster_created, self)
  end
end

