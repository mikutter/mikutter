# -*- coding: utf-8 -*-
#
# ruby config loader
#

miquire :core, 'environment'
miquire :core, 'serialthread'
miquire :miku, 'miku'
miquire :lib, 'timelimitedqueue'

require 'fileutils'
require 'set'
require 'yaml'

=begin rdoc
  オブジェクトにデータ保存機能をつけるmix-in
  includeすると、key-value形で恒久的にデータを保存するためのメソッドが提供される。
  mikutter, CHIのプラグインでは通常はUserConfigをつかうこと。
=end
module ConfigLoader
  STORAGE_FILE = File.expand_path(File.join(Environment::SETTINGDIR, "setting.yml"))
  TMP_FILE = File.expand_path(File.join(Environment::SETTINGDIR, "setting.writing.yml"))
  PSTORE_FILE = File.expand_path(File.join(Environment::CONFROOT, "p_class_values.db"))
  AVAILABLE_TYPES = [Hash, Array, Set, Numeric, String, Symbol, Time, NilClass, TrueClass, FalseClass].freeze

  @@configloader_cache = nil
  @@configloader_queue ||= TimeLimitedQueue.new(HYDE, 5, Set){ |keys|
    File.open(TMP_FILE, 'w'.freeze){ |tmpfile|
      YAML.dump(@@configloader_cache, tmpfile)
    }
    FileUtils.mv TMP_FILE, STORAGE_FILE
    notice "configloader: wrote #{keys.size} keys (#{keys.to_a.join(', ')})" }

  class << self

    # 一度だけ自動的に呼ばれる(このソースファイルの一番下の方)
    # メモリ上に設定データを読み込む。
    # YAMLがなければ、旧データ形式(PStore)からデータを読み込む。
    def boot
      @@configloader_cache = if FileTest.exist?(STORAGE_FILE)
                               notice "load setting data from #{STORAGE_FILE}"
                               YAML.load_file(STORAGE_FILE)
                             elsif FileTest.exist?(PSTORE_FILE)
                               notice "load setting data from #{PSTORE_FILE}"
                               ConfigLoader.migration_from_pstore
                             else
                               notice "setting data not found"
                               Hash.new end end

    # 旧データ形式(PStore)からデータを取得して返す
    # ==== Return
    # 設定データ(Hash)
    def migration_from_pstore
      require 'pstore'
      PStore.new(PSTORE_FILE).transaction(true) { |db|
        config = Hash.new
        db.roots.each { |key|
          config[key] = db[key] }
        config } end

    # _obj_ が保存可能な値なら _obj_ を返す。そうでなければ _ArgumentError_ 例外を投げる。
    def validate(obj)
      if AVAILABLE_TYPES.any?{|x| obj.is_a?(x)}
        if obj.is_a? Hash
          result = {}
          obj.each{ |key, value|
            result[self.validate(key)] = self.validate(value) }
          result.freeze
        elsif obj.is_a? Enumerable
          obj.map(&method(:validate)).freeze
        elsif not(obj.freezable?) or obj.frozen?
          obj
        else
          obj.dup.freeze end
      else
        emes = "ConfigLoader recordable class of #{AVAILABLE_TYPES.join(',')} only. but #{obj.class} given."
        error(emes)
        raise ArgumentError.new(emes)
      end
    end

  end

  # _key_ に対応するオブジェクトを取り出す。
  # _key_ が存在しない場合は nil か _ifnone_ を返す
  def at(key, ifnone=nil)
    ckey = configloader_key(key)
    if @@configloader_cache.has_key? ckey
      @@configloader_cache[ckey]
    else
      ifnone end end

  # _key_ にたいして _val_ を関連付ける。
  def store(key, val)
    ConfigLoader.validate(key)
    val = ConfigLoader.validate(val)
    ckey = configloader_key(key)
    @@configloader_cache[ckey] = val
    @@configloader_queue.push(ckey)
    val end

  private

  def configloader_key(key)
    "#{self.class.to_s}::#{key}".freeze end
  memoize :configloader_key

  boot

end
