# -*- coding: utf-8 -*-
# ウィンドウパーツ階層構造の親
# これをincludeするクラスは、クラスメソッドとしてactiveを実装している必要がある

module Plugin::GUI::HierarchyParent

  class << self
    def included(klass)
      klass.extend(Extended)
    end
  end

  attr_reader :active_child

  # 子を追加する
  # ==== Args
  # [child] 子のインスタンス
  # ==== Return
  # self
  def <<(child)
    type_strict child => Plugin::GUI::HierarchyChild
    children << child
    child.set_parent(self)
    @active_child ||= child
    self end
  alias add_child <<

  # 子を削除する
  # ==== Args
  # [child] 削除する子
  # ==== Return
  # self
  def remove(child)
    children.delete(child)
    if @active_child == child
      @active_child = nil end
    self end

  # 子の配列を返す
  # ==== Return
  # 子の配列
  def children
    @children ||= [] end

  def set_active_child(child)
    type_strict child => tcor(Plugin::GUI::HierarchyChild, NilClass)
    @active_child = child
    notice "active child set #{self.inspect} => #{child.inspect}"
    self end

  # このインスタンス以下の、アクティブな祖先のリストを返す。
  # ==== Return
  # アクティブな子、孫、…のリスト 又は空の配列
  def active_chain
    if @active_child
      result = [@active_child]
      ancestors = @active_child.respond_to?(:active_chain) && @active_child.active_chain
      ancestors ? result + ancestors : result
    else
      [] end end

  # active_ancestor が返すインスタンスのうち、最初に _klass_ とis_a関係にあるものを返す。
  # ==== Args
  # [klass] クラス
  # ==== Return
  # 一致する祖先か見つからなければnil
  def active_class_of(klass)
    active_chain.find{ |child| child.is_a? klass } end

  module Extended
    # 子を追加するデフォルトのインスタンスを返す
    def add_default
      active end
  end
end
