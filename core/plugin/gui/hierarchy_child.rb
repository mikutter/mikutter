# -*- coding: utf-8 -*-
# ウィンドウパーツ階層構造の子

module Plugin::GUI::HierarchyChild

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
    type_strict parent => @parent_class
    @parent = parent end

  def active_class_of(klass)
    self if is_a? klass end

  # 先祖のうち、 _klass_ と is_a? 関係にあるものを返す
  # ==== Args
  # [klass] 探すクラス
  # ==== Return
  # マッチしたウィジェットかfalse
  def ancestor_of(klass)
    if self.is_a? klass
      self
    elsif @parent.is_a? Plugin::GUI::HierarchyChild
      @parent.ancestor_of(klass)
    else @parent.is_a? klass
      @parent end end

  # 親を再帰的に辿り、selfをアクティブに設定する
  # ==== Return
  # self
  def active!
    @parent.set_active_child(self).active!
    self end

  module Extended
    attr_reader :parent_class

    # 親クラスを設定する。親にはこのクラスのインスタンス以外認めない
    # ==== Args
    # [klass] 親クラス
    def set_parent_class(klass)
      @parent_class = klass end

    # 親クラスを再帰的にたどっていって、一番上の親クラスを返す
    def ancestor
      if @parent_class.respond_to? :ancestor
        @parent_class.ancestor
      else
        @parent_class end end

    # 現在アクティブなインスタンスを返す
    # ==== Return
    # アクティブなインスタンス又はnil
    def active
      widget = ancestor.active
      widget.active_class_of(self) if widget end
  end

end
