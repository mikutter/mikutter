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

  confroot = File.expand_path(File.join("~", ".#{ACRO}"))
  # コンフィグファイルのディレクトリ
  CONFROOT = (if Mopt.confroot then Mopt.confroot else confroot end) rescue confroot

  # 一時ディレクトリ
  TMPDIR = File.join(CONFROOT, 'tmp')

  # ログディレクトリ
  LOGDIR = File.join(CONFROOT, 'log')

  # キャッシュディレクトリ
  CACHE = File.join(CONFROOT, 'cache')

  # AutoTag有効？
  AutoTag = false

  # 再起動後に、前回取得したポストを取得しない
  NeverRetrieveOverlappedMumble = false

  REVISION = 1150

  # このソフトのバージョン。
  VERSION = [0,2,2,REVISION]

end
