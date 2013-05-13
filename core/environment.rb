# -*- coding: utf-8 -*-
#
# Envirionment
#

# 変更不能な設定たち
# コアで変更されるもの
# CHIの設定

miquire :core, 'config'

module Environment
  # このアプリケーションの名前。
  NAME = CHIConfig::NAME

  # 名前の略称
  ACRO = CHIConfig::ACRO

  # 下の２行は馬鹿にしか見えない
  TWITTER_CONSUMER_KEY = CHIConfig::TWITTER_CONSUMER_KEY
  TWITTER_CONSUMER_SECRET = CHIConfig::TWITTER_CONSUMER_SECRET
  TWITTER_AUTHENTICATE_REVISION = CHIConfig::TWITTER_AUTHENTICATE_REVISION

  # pidファイル
  PIDFILE = CHIConfig::PIDFILE

  # コンフィグファイルのディレクトリ
  CONFROOT = CHIConfig::CONFROOT

  # 一時ディレクトリ
  TMPDIR = CHIConfig::TMPDIR

  # ログディレクトリ
  LOGDIR = CHIConfig::LOGDIR

  # キャッシュディレクトリ
  CACHE = CHIConfig::CACHE

  # プラグインディレクトリ
  PLUGIN_PATH = CHIConfig::PLUGIN_PATH

  # AutoTag有効？
  AutoTag = CHIConfig::AutoTag

  # 再起動後に、前回取得したポストを取得しない
  NeverRetrieveOverlappedMumble = CHIConfig::NeverRetrieveOverlappedMumble

  class Version
    include Comparable

    attr_reader :mejor, :minor, :debug, :devel

    def initialize(mejor, minor, debug, devel)
      @mejor = mejor
      @minor = minor
      @debug = debug
      @devel = devel
    end

    def to_a
      [@mejor, @minor, @debug, @devel]
    end

    def to_s
      self.to_a.join('.')
    end

    def to_i
      @mejor
    end

    def to_f
      @mejor + @minor/100
    end

    def inspect
      "#{Environment::NAME} ver.#{self.to_s}"
    end

    def size
      4
    end

    def <=>(other)
      if other.size == 4 then
        self.to_a <=> other.to_a
      end
    end

  end

  # このソフトのバージョン。
  VERSION = Version.new(*CHIConfig::VERSION)

end
