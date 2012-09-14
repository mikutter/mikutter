# -*- coding: utf-8 -*-
# ウィンドウパーツ階層構造の親
# これをincludeするクラスは、クラスメソッドとしてactiveを実装している必要がある
module Plugin::GUI::HierarchyParent

  class << self
    def included(klass)
      klass.extend(Extended)
    end
  end

  # 子を追加する
  # ==== Args
  # [child] 子のインスタンス
  # ==== Return
  # self
  def <<(child)
    children << child
    child.set_parent(self)
    self end

  # 子の配列を返す
  # ==== Return
  # 子の配列
  def children
    @children ||= [] end

  module Extended
    # 子を追加するデフォルトのインスタンスを返す
    def add_default
      active end
  end
end
