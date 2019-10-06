# -*- coding: utf-8 -*-
#
# Config
#

# アプリケーションごとの設定たち
# mikutterの設定

module CHIConfig
  # このアプリケーションの名前。
  NAME = "mikutter"

  # 名前の略称
  ACRO = "mikutter"

  # 下の２行は馬鹿にしか見えない
  TWITTER_CONSUMER_KEY = "AmDS1hCCXWstbss5624kVw"
  TWITTER_CONSUMER_SECRET = "KOPOooopg9Scu7gJUBHBWjwkXz9xgPJxnhnhO55VQ"
  TWITTER_AUTHENTICATE_REVISION = 1

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
  PLUGIN_PATH = File.expand_path(File.join(File.dirname(__FILE__), "plugin"))

  # AutoTag有効？
  AutoTag = false

  # 再起動後に、前回取得したポストを取得しない
  NeverRetrieveOverlappedMumble = false

  # このソフトのバージョン。
  VERSION = [3,9,6,9999]

end
