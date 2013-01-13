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
  CONFROOT = "~#{File::SEPARATOR}.#{ACRO}#{File::SEPARATOR}"

  # 一時ディレクトリ
  TMPDIR = "~#{File::SEPARATOR}.#{ACRO}#{File::SEPARATOR}tmp#{File::SEPARATOR}"

  # ログディレクトリ
  LOGDIR = "~#{File::SEPARATOR}.#{ACRO}#{File::SEPARATOR}log#{File::SEPARATOR}"

  # キャッシュディレクトリ
  CACHE = "#{CONFROOT}cache#{File::SEPARATOR}"

  # AutoTag有効？
  AutoTag = false

  # 再起動後に、前回取得したポストを取得しない
  NeverRetrieveOverlappedMumble = false

  REVISION = 1119

  # このソフトのバージョン。
  VERSION = [0,2,1, ((/Last Changed Rev\s*:\s*(\d+)/.match(`sh -c 'LC_ALL=C svn info ../'`)[1] || REVISION).to_i rescue REVISION)]

end
