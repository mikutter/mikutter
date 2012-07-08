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

  def inspect
    "#<#{self.class.to_s}(role=#{self.class.role},slug=#{slug})>"
  end

  def to_s
    inspect
  end

end
