# -*- coding: utf-8 -*-
# タブとかペインみたいにたくさん作れるパーツ

module Plugin::GUI::Cuscadable
  attr_reader :slug, :name

  class << self
    def included(klass)
      klass.instance_eval{
        private
        alias new_cuscadable new
        def new(slug, name)
          type_strict slug => Symbol, name => String
          new_cuscadable(slug, name) end }
      klass.extend ExtendedCuscadable end end

  def initialize(slug, name)
    @slug = slug
    @name = name.freeze
    self.class.regist(self) end

  # 次のインスタンスを返す。このインスタンスが最後だった場合は最初に戻る
  def next
    values = self.class.cuscaded.values
    instance, index = values.each_with_index.find{ |instance, index| self.equal?(instance) }
    index += 1
    index -= values.size if index >= values.size
    values[index] end

  # 前のインスタンスを返す。このインスタンスが最初だった場合は最後に戻る
  def prev
    values = self.class.cuscaded.values
    instance, index = values.each_with_index.find{ |instance, index| self.equal?(instance) }
    index -= 1
    index += values.size if index < 0
    values[index] end

  module ExtendedCuscadable
    # アクティブなインスタンス
    attr_reader :active

    # タブ _slug_ に対するインターフェイスを作成。
    # _slug_ に対応するタブがない場合は作成する。
    # ==== Args
    # [slug] スラッグ(Symbol)
    # [name] タブのラベル(String)
    def instance(slug, name = slug.to_s)
      type_strict slug => Symbol, name => String
      if cuscaded.has_key? slug
        cuscaded[slug]
      else
        new(slug, name) end end

    # 新しく作成したタブを新規登録する
    # ==== Args
    # [tab] タブ
    # ==== Return
    # self
    def regist(tab)
      cuscaded[tab.slug] ||= tab
      @active ||= tab
      self end

    # インスタンスの一覧を取得する
    # ==== Return
    # インスタンスの配列
    def cuscaded
      @cuscaded ||= {}          # slug => instance
    end

  end

end

