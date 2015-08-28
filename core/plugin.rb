# -*- coding: utf-8 -*-

require 'pluggaloid'
miquire :core, 'configloader'

Event = Pluggaloid::Event

EventListener = Pluggaloid::Listener

EventFilter = Pluggaloid::Filter

class Plugin < Pluggaloid::Plugin
  include ConfigLoader

  class << self
    def activity(kind, title, args = {})
      Plugin.call(:modify_activity,
                  { plugin: nil,
                    kind: kind,
                    title: title,
                    date: Time.new,
                    description: title }.merge(args)) end
  end

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

  # mikutterコマンドを定義
  # ==== Args
  # [slug] コマンドスラッグ
  # [options] コマンドオプション
  # [&exec] コマンドの実行内容
  def command(slug, options, &exec)
    command = options.merge(slug: slug, exec: exec, plugin: @name).freeze
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

  # 画像ファイルのパスを得る
  # ==== Args
  # - String filename ファイル名
  def get_skin(filename)
    plugin_skin_dir = File.join(spec[:path], "skin")
    if File.exist?(plugin_skin_dir)
      Skin.get(filename, [plugin_skin_dir])
    else
      Skin.get(filename)
    end
  end

end

Plugin.vm.Plugin = Plugin
