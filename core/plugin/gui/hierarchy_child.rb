# -*- coding: utf-8 -*-
# ウィンドウパーツ階層構造の子

class Plugin::GUI::HierarchyChild
  class << self
    def included(klass)
      klass.extend(Extended)
    end
  end

  attr_reader :parent

  # 親を _parent_ に設定
  # ==== Args
  # [parent] 親
  # ==== Return
  # self
  def set_parent(parent)
    @parent = parent end

  class Extended
  end

end
