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

  # pidファイル
  PIDFILE = "#{File::SEPARATOR}tmp#{File::SEPARATOR}mikutter.pid"

  # コンフィグファイルのディレクトリ
  CONFROOT = "~#{File::SEPARATOR}.mikutter#{File::SEPARATOR}"

  # 一時ディレクトリ
  TMPDIR = "~#{File::SEPARATOR}.mikutter#{File::SEPARATOR}tmp#{File::SEPARATOR}"

  # ログディレクトリ
  LOGDIR = "~#{File::SEPARATOR}.mikutter#{File::SEPARATOR}log#{File::SEPARATOR}"

  # キャッシュディレクトリ
  CACHE = "#{CONFROOT}cache#{File::SEPARATOR}"

  # AutoTag有効？
  AutoTag = false

  # 再起動後に、前回取得したポストを取得しない
  NeverRetrieveOverlappedMumble = false

  # このソフトのバージョン。
  VERSION = [0,0,3,5]

end

