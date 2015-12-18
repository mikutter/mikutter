# -*- coding: utf-8 -*-
# タブとかペインみたいにたくさん作れるパーツ

module Plugin::GUI::Cuscadable
  attr_reader :slug, :plugin
  attr_accessor :name

  class << self
    def included(klass)
      klass.instance_eval{
        private
        alias new_cuscadable new
        def new(slug, name, plugin)
          type_strict slug => Symbol, name => String, plugin => tcor(NilClass, Symbol)
          new_cuscadable(slug, name, plugin) end }
      klass.extend ExtendedCuscadable end end

  def initialize(slug, name, plugin_name)
    @slug, @name, @plugin = slug, name.freeze, plugin_name
    @unload_hook = nil
    if plugin_name
      plugin = Plugin.instance(plugin_name)
      if plugin
        notice "attach unload hook. plugin:#{plugin}, widget: #{self}"
        @unload_hook = plugin.onunload{
          notice "widget destroy triggered off detach plugin #{@plugin}. widget: #{self}"
          destroy } end end
    self.class.register(self) end

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
    extend Gem::Deprecate

    # タブ _slug_ に対するインターフェイスを作成。
    # _slug_ に対応するタブがない場合は作成する。
    # ==== Args
    # [slug] スラッグ(Symbol)
    # [name] タブのラベル(String)
    # [plugin] タブを作成したプラグイン
    def instance(slug = nil, name=slug, plugin=nil)
      if not slug
        slug = "__#{self.to_s}_#{Process.pid}_#{Time.now.to_i.to_s(16)}_#{rand(2 ** 32).to_s(16)}".to_sym
        return instance if cuscaded.has_key? slug end
      type_strict slug => Symbol, name => :to_s
      if cuscaded.has_key? slug
        imaginally = cuscaded[slug]
        if name != slug and name != imaginally
          imaginally.name = name
        end
        imaginally
      else
        new(slug, name.to_s, plugin) end end

    # 新しく作成したタブを新規登録する
    # ==== Args
    # [tab] タブ
    # ==== Return
    # self
    def register(tab)
      cuscaded[tab.slug] ||= tab
      self end
    alias :regist :register
    deprecate :regist, "register", 2016, 12

    # インスタンスの一覧を取得する
    # ==== Return
    # インスタンスの配列
    def cuscaded
      @cuscaded ||= {}          # slug => instance
    end

    # そのスラッグを持つインスタンスがあるかどうかを調べる
    # ==== Args
    # [slug] スラッグ
    # ==== Return
    # スラッグslugを持つインスタンスが既にあれば真
    def exist?(slug)
      @cuscaded.has_key?(slug) end

  end

end
