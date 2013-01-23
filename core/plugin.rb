# -*- coding: utf-8 -*-

miquire :core, 'configloader', 'environment', 'delayer', 'event', 'event_listener', 'event_filter'
miquire :lib, "instance_storage"

# プラグインの本体。
# DSLを提供し、イベントやフィルタの管理をする
class Plugin
  include ConfigLoader
  include InstanceStorage

  class << self
    # プラグインのインスタンスを返す。
    # ブロックが渡された場合、そのブロックをプラグインのインスタンスのスコープで実行する
    # ==== Args
    # [plugin_name] プラグイン名
    # ==== Return
    # Plugin
    def create(plugin_name, &body)
      type_strict plugin_name => Symbol
      Plugin[plugin_name].instance_eval(&body) if body
      if defined?(@load_hook[plugin_name]) and @load_hook[plugin_name]
        @load_hook[plugin_name].each &:call
        @load_hook.delete(plugin_name) end
      Plugin[plugin_name] end

    # イベントを宣言する。
    # ==== Args
    # [event_name] イベント名
    # [options] 以下のキーを持つHash
    # :prototype :: 引数の数と型。Arrayで、type_strictが解釈できる条件を設定する
    # :priority :: Delayerの優先順位
    def defevent(event_name, options = {})
      type_strict event_name => Symbol, options => Hash
      Event[event_name].options = options end

    # イベント _event_name_ を発生させる
    # ==== Args
    # [event_name] イベント名
    # [*args] イベントの引数
    # ==== Return
    # Delayer
    def call(event_name, *args)
      type_strict event_name => Symbol
      Event[event_name].call(*args) end

    # 引数 _args_ をフィルタリングした結果を返す
    # ==== Args
    # [*args] 引数
    # ==== Return
    # フィルタされた引数の配列
    def filtering(event_name, *args)
      type_strict event_name => Symbol
      Event[event_name].filtering(*args)
    end

    # 互換性のため
    def uninstall(plugin_name)
      self[plugin_name].uninstall
    end

    # 互換性のため
    def filter_cancel!
      EventFilter.cancel! end

    alias plugin_list instances_name

    # ファイル _path_ を実行し、プラグインを読み込む。
    # ==== Args
    # [path] ruby スクリプトファイルのパス
    # [spec] specの内容(Hash)
    def load_file(path, spec)
      type_strict path => String, spec[:slug] => :to_sym
      still_not_load = lazy{ (spec[:depends][:plugin].map(&:to_sym) - plugin_list) }
      if defined?(spec[:depends]) and spec[:depends].is_a? Array
        spec[:depends] = { plugin: spec[:depends] } end
      if defined?(spec[:depends][:plugin]) and not still_not_load.empty?
        still_not_load.each{ |depend|
          load_hook(depend){
            still_not_load.delete(depend)
            if still_not_load.empty?
              require path
              Plugin.create(spec[:slug].to_sym){ @spec = spec } end } }
      else
        require path
        Plugin.create(spec[:slug].to_sym){ @spec = spec } end end

    alias __clear_aF4e__ clear!
    def clear!
      Event.clear!
      __clear_aF4e__()
    end

    private

    def load_hook(slug, &callback)
      type_strict slug => Symbol, callback => Proc
      @load_hook ||= {}
      @load_hook[slug] ||= []
      @load_hook[slug] << callback end
  end

  # プラグインの名前
  attr_reader :name

  # ==== Args
  # [plugin_name] プラグイン名
  def initialize(*args)
    super
    @events = Set.new
    @filters = Set.new end

  # イベントリスナを新しく登録する
  # ==== Args
  # [event_name] イベント名
  # [&callback] イベントのコールバック
  # ==== Return
  # EventListener
  def add_event(event_name, &callback)
    type_strict event_name => :to_sym, callback => :call
    result = EventListener.new(Event[event_name.to_sym], &callback)
    @events << result
    result end

  # イベントフィルタを新しく登録する
  # ==== Args
  # [event_name] イベント名
  # [&callback] イベントのコールバック
  # ==== Return
  # EventFilter
  def add_event_filter(event_name, &callback)
    type_strict event_name => :to_sym, callback => :call
    result = EventFilter.new(Event[event_name.to_sym], &callback)
    @filters << result
    result end

  # イベントを削除する。
  # 引数は、EventListenerかEventFilterのみ(on_*やfilter_*の戻り値)。
  # 互換性のため、二つ引数がある場合は第一引数は無視され、第二引数が使われる。
  # ==== Args
  # [*args] 引数
  # ==== Return
  # self
  def detach(*args)
    listener = args.last
    if listener.is_a? EventListener
      @events.delete(listener)
      listener.detach
    elsif listener.is_a? EventFilter
      @filters.delete(listener)
      listener.detach end
    self end

  # このプラグインを破棄する
  # ==== Return
  # self
  def uninstall
    @events.map &:detach
    @filters.map &:detach
    self.class.destroy name
    execute_unload_hook
    self end

  # プラグインストレージの _key_ の値を取り出す
  # ==== Args
  # [key] 取得するキー
  # [ifnone] キーに対応する値が存在しない場合
  # ==== Return
  # プラグインストレージ内のキーに対応する値
  def at(key, ifnone=nil)
    super("#{@name}_#{key}".to_sym, ifnone) end

  # プラグインストレージに _key_ とその値 _vel_ の対応を保存する
  # ==== Args
  # [key] 取得するキー
  # [val] 値
  def store(key, val)
    super("#{@name}_#{key}".to_sym, val) end

  # イベント _event_name_ を宣言する
  # ==== Args
  # [event_name] イベント名
  # [options] イベントの定義
  def defevent(event_name, options={})
    Event[event_name].options.merge!({plugin: self}.merge(options)) end

  # プラグインが Plugin.uninstall される時に呼ばれるブロックを登録する。
  def onunload
    @unload_hook ||= []
    @unload_hook.push(Proc.new) end
  alias :on_unload :onunload

  # mikutterコマンドを定義
  # ==== Args
  # [slug] コマンドスラッグ
  # [options] コマンドオプション
  # [&exec] コマンドの実行内容
  def command(slug, options, &exec)
    command = options.merge(slug: slug, exec: exec).freeze
    add_event_filter(:command){ |menu|
      menu[slug] = command
      [menu] } end

  # 設定画面を作る
  # ==== Args
  # - String name タイトル
  # - Proc &place 設定画面を作る無名関数
  def settings(name, &place)
    add_event_filter(:defined_settings) do |tabs|
      [tabs.melt << [name, place, @name]] end end

  # マジックメソッドを追加する。
  # on_?name :: add_event(name)
  # filter_?name :: add_event_filter(name)
  def method_missing(method, *args, &proc)
    case method.to_s
    when /^on_?(.+)$/
       add_event($1.to_sym, &proc)
    when /^filter_?(.+)$/
       add_event_filter($1.to_sym, &proc)
    when /^hook_?(.+)$/
      add_event_hook($1.to_sym, &proc)
    else
      super end end

  private

  def execute_unload_hook
    @unload_hook.each{ |unload| unload.call } if(defined?(@unload_hook)) end

end
