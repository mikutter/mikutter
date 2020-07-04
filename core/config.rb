# frozen_string_literal: true
# -*- coding: utf-8 -*-
#
# Config
#

# アプリケーションごとの設定たち
# mikutterの設定

module CHIConfig
  # このアプリケーションの名前。
  NAME = 'mikutter'

  # 名前の略称
  ACRO = 'mikutter'

  # pidファイル
  PIDFILE = "#{File::SEPARATOR}tmp#{File::SEPARATOR}#{ACRO}.pid"

  # コンフィグファイルのディレクトリ
  CONFROOT = Mopt.confroot rescue File.expand_path('~/.mikutter')

  # 一時ディレクトリ
  TMPDIR = File.join(CONFROOT, 'tmp')

  # ログディレクトリ
  LOGDIR = File.join(CONFROOT, 'log')

  # プラグインの設定等
  SETTINGDIR = File.join(CONFROOT, 'settings')

  # キャッシュディレクトリ
  CACHE = File.join(CONFROOT, 'cache')

  # プラグインディレクトリ
  PLUGIN_PATH = File.expand_path(File.join(__dir__, '..', 'plugin'))

  # AutoTag有効？
  AutoTag = false

  # 再起動後に、前回取得したポストを取得しない
  NeverRetrieveOverlappedMumble = false

  # このソフトのバージョン。
  VERSION = [4,0,6,9999]

end
