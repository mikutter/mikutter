# -*- coding: utf-8 -*-
#
# Config
#

# アプリケーションごとの設定たち
# mikutterの設定

module Config
  # このアプリケーションの名前。
  NAME = "mikutter"

  # 名前の略称
  ACRO = "mikutter"

  # pidファイル
  PIDFILE = "#{File::SEPARATOR}tmp#{File::SEPARATOR}mikutter.pid"

  # コンフィグファイルのディレクトリ
  CONFROOT = "~#{File::SEPARATOR}.mikutter#{File::SEPARATOR}"

  # 一時ディレクトリ
  TMPDIR = "~#{File::SEPARATOR}.mikutter#{File::SEPARATOR}tmp#{File::SEPARATOR}"

  # ログディレクトリ
  LOGDIR = "~#{File::SEPARATOR}.mikutter#{File::SEPARATOR}log#{File::SEPARATOR}"

  # AutoTag有効？
  AutoTag = false

  # 再起動後に、前回取得したポストを取得しない
  NeverRetrieveOverlappedMumble = false

  # このソフトのバージョン。
  VERSION = [0,0,1,0]

end

