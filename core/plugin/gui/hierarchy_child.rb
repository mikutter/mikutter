# -*- coding: utf-8 -*-
# ウィンドウパーツ階層構造の子

module Plugin::GUI::HierarchyChild

  class << self
    def included(klass)
      if klass.include?(Plugin::GUI::HierarchyParent)
        raise "Plugin::GUI::HierarchyChild must be included before the Plugin::GUI::HierarchyParent."
      end
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
    return self if @parent == parent
    @parent.remove(self) if @parent
    @parent = parent
    if self.class.set_parent_event
      Plugin.call(self.class.set_parent_event, self, parent) end
    self end

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
  # ==== Args
  # [just_this] 再帰的に呼び出されたのではなく、直接これをアクティブに指定されたなら真
  # [by_toolkit] UIツールキットの入力でアクティブになった場合真
  # ==== Return
  # self
  def active!(just_this=true, by_toolkit=false)
    @parent.set_active_child(self, by_toolkit).active!(false, by_toolkit)
    self end

  module Extended
    attr_reader :parent_class

    # set_parentが呼ばれた時に発生させるイベントを設定する
    def set_parent_event(event = nil)
      if event
        @set_parent_event = event
      else
        @set_parent_event end end

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
