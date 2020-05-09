# -*- coding: utf-8 -*-
# ウィンドウパーツ共通

module Plugin::GUI::Widget

  class << self
    def included(klass)
      klass.extend(Extended)
    end
  end

  module Extended
    # このクラスのロールを _new_ に設定する。また、引数なしで呼び出した場合は現在のロールを返す
    # ==== Args
    # [new] 新しいロール
    # ==== Return
    # 新しいロール。 _new_ が省略された場合は現在のロール
    def role(new = nil)
      if new
        @role = new
      else
        @role end end

    # 自分と先祖の中から _role_ をもつクラスを探す
    # ==== Args
    # [find] 探すロール
    # ==== Return
    # 先祖にロール _role_ をもつクラスがあればそのクラス、無ければnil
    def find_role_ancestor(find)
      if role == find
        self
      elsif respond_to? :parent_class and parent_class
        parent_class.find_role_ancestor(find) end end
  end

  # ツールキット上で、このウィジェットを破棄する。
  # 親からは自動的に切り離される。
  # ==== Return
  # self
  def destroy
    if not destroyed?
      Plugin.call(:gui_destroy, self)
      self.class.cuscaded.delete(slug)
      @destroy = true
      if @unload_hook and self.plugin
        plugin = Plugin.instance(self.plugin)
        if plugin
          plugin.detach(:unload, @unload_hook) end end end
    self end

  # ツールキット上で、ウィジェットが削除されているかどうかを調べる。
  # 削除待ちの場合も真を返す。
  # ==== Return
  # 削除されているなら真
  def destroyed?
    return true if defined?(@destroy) and @destroy
    Plugin.filtering(:gui_destroyed, self).first end

  # ブロックをselfに対してinstance_evalする。
  # その間、selfに対して呼ばれたメソッドで存在しないものは、 _delegate_ のものを呼ぶ。
  # ==== Args
  # [delegate] BasicObject 任意のオブジェクト
  # [*rest] procに渡す引数
  # [&proc] 実行するブロック
  # ==== Return
  # ブロックの戻り値
  def instance_eval_with_delegate(delegate, *rest, &proc)
    before_delegatee = @delegate
    begin
      @delegate = delegate
      instance_exec(*rest, &proc)
    ensure
      @delegate = before_delegatee
    end
  end

  def inspect
    "#<#{self.class.to_s}(role=#{self.class.role},slug=#{slug})>"
  end

  def to_s
    inspect
  end

  # 自分以下の子を、{slug: {slug: ...}}形式の連想配列で返す
  # ==== Return
  # 親子関係の連想配列
  def to_h
    if is_a? Plugin::GUI::HierarchyParent
      result = {}
      children.each{ |child|
        result[child.slug] = child.to_h }
      result end end

  def method_missing(*args, &block)
    if defined?(@delegate) and @delegate
      @delegate.__send__(*args, &block)
    else
      super end end

end
