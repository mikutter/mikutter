# -*- coding: utf-8 -*-

require 'pluggaloid'
miquire :core, 'configloader'

Event = Pluggaloid::Event

EventListener = Pluggaloid::Listener

EventFilter = Pluggaloid::Filter

class Plugin < Pluggaloid::Plugin
  include ConfigLoader

  class << self
    # ユーザに向けて通知を発生させる。
    # 通知は、activityプラグインなど、通知の表示に対応するプラグインが
    # 入っていればユーザがそれを確認することができるが、そのようなプラグインがない場合は
    # 通知は単に無視される。
    # プラグインから通知を発生させたい場合は、 Plugin.Activity のかわりに
    # Plugin#activity を使えば、通知を発生させたプラグインを特定できるようになる
    #
    # 引数は、 Plugin#activityを参照
    def activity(kind, title, args = {})
      Plugin.call(:modify_activity,
                  { plugin: nil,
                    kind: kind,
                    title: title,
                    date: Time.new,
                    description: title }.merge(args)) end
  end

  # ユーザに向けて通知を発生させる。
  # 通知は、activityプラグインなど、通知の表示に対応するプラグインが
  # 入っていればユーザがそれを確認することができるが、そのようなプラグインがない場合は
  # 通知は単に無視される。
  # ==== Args
  # [kind] Symbol 通知の種類
  # [title] String 通知のタイトル
  # [args] Hash その他オプション。主に以下の値
  #   icon :: String|GdkPixbuf::Pixbuf アイコン
  #   date :: Time イベントの発生した時刻
  #   service :: Service 関係するServiceオブジェクト
  #   related :: 自分に関係するかどうかのフラグ
  def activity(kind, title, args={})
    Plugin.call(:modify_activity,
                { plugin: self,
                  kind: kind,
                  title: title,
                  date: Time.new,
                  description: title }.merge(args))
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
