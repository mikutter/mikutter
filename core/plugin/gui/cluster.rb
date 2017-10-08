# -*- coding: utf-8 -*-
# プロフィールタブを提供するクラス

require_relative 'cuscadable'
require_relative 'hierarchy_parent'
require_relative 'hierarchy_child'
require_relative 'window'
require_relative 'widget'

class Plugin::GUI::Cluster

  include Plugin::GUI::Cuscadable
  include Plugin::GUI::HierarchyChild
  include Plugin::GUI::HierarchyParent
  include Plugin::GUI::Widget

  role :cluster

  set_parent_event :gui_cluster_join_tab

  # instanceから呼ばれる。勝手に作成しないこと
  def initialize(*args)
    super
    Plugin.call(:cluster_created, self)
  end
end



