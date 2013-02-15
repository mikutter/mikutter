# -*- coding: utf-8 -*-
#
# ruby config loader
#

require File.expand_path('utils')
miquire :core, 'environment'
miquire :core, 'serialthread'
miquire :miku, 'miku'
miquire :lib, 'timelimitedqueue'

require 'fileutils'
require 'thread'
require 'set'

=begin rdoc
  オブジェクトにデータ保存機能をつけるmix-in
  includeすると、key-value形で恒久的にデータを保存するためのメソッドが提供される。
  mikutter, CHIのプラグインでは通常はUserConfigをつかうこと。
=end
module ConfigLoader
  SAVE_FILE = File.expand_path(File.join(Environment::CONFROOT, "p_class_values.db"))
  BACKUP_FILE = "#{SAVE_FILE}.bak"
  AVAILABLE_TYPES = [Hash, Array, Numeric, String, Symbol, NilClass, TrueClass, FalseClass].freeze

  @@configloader_pstore = nil
  @@configloader_cache = Hash.new
  @@configloader_queue = TimeLimitedQueue.new{ |data|
    detected = Array.new
    ConfigLoader.transaction{
      data.each{ |pair|
        key, val = *pair
        detected << key
        begin
          ConfigLoader.pstore[key] = val
        rescue => e
          error e end } }
    notice "configloader: wrote #{detected.size} keys (#{detected.join(', ')})"
  }

  # _key_ に対応するオブジェクトを取り出す。
  # _key_ が存在しない場合は nil か _ifnone_ を返す
  def at(key, ifnone=nil)
    ckey = configloader_key(key)
    @@configloader_cache[ckey] ||= ConfigLoader.transaction(true){
      if ConfigLoader.pstore.root?(ckey)
        to_utf8(ConfigLoader.pstore[ckey]).freeze
      elsif defined? yield
        yield(key, ifnone).freeze
      else
        ifnone end } end

  # _key_ にたいして _val_ を関連付ける。
  def store(key, val)
    ConfigLoader.validate(key)
    ConfigLoader.validate(val)
    ckey = configloader_key(key)
    @@configloader_queue.push([ckey, val])
    if(val.frozen?)
      @@configloader_cache[ckey] = val
    else
      @@configloader_cache[ckey] = (val.clone.freeze rescue val) end end

  # ConfigLoader#store と同じ。ただし、値を変更する前に _key_ に関連付けられていた値を返す。
  # もともと関連付けられていた値がない場合は _val_ を返す。
  def store_before_at(key, val)
    result = self.at(key)
    self.store(key, val)
    result or val end

  private

  # _obj_ が保存可能な値なら _obj_ を返す。そうでなければ _ArgumentError_ 例外を投げる。
  def self.validate(obj)
    if AVAILABLE_TYPES.any?{|x| obj.is_a?(x)}
      obj
    else
      emes = "ConfigLoader recordable class of #{AVAILABLE_TYPES.join(',')} only. but #{obj.class} gaven."
      error(emes)
      raise ArgumentError.new(emes)
    end
  end

  # Ruby1.9の文字列のM17N対策
  # 1.8では直ちにselfを返す
  if(''.respond_to? :force_encoding)
    def to_utf8(a)
      unless(a.frozen?)
        if(a.is_a? Array)
          a.freeze
          return a.map &method(:to_utf8).freeze
        elsif(a.is_a? Hash)
          r = Hash.new
          a.freeze
          a.each{ |key, val|
            r[to_utf8(key)]= to_utf8(val) }
          return r.freeze
        elsif(a.respond_to? :force_encoding)
          return a.dup.force_encoding(Encoding::UTF_8).freeze rescue a end end
      a end
  else
    def to_utf8(a)
      a end end

  def configloader_key(key)
    "#{self.class.to_s}::#{key}".freeze end
  memoize :configloader_key

  def self.transaction(ro = false)
    self.pstore.transaction(ro){ |pstore|
      yield(pstore) } end

  def self.pstore
    if not(@@configloader_pstore) then
      FileUtils.mkdir_p(File.expand_path(File.dirname(SAVE_FILE)))
      @@configloader_pstore = HatsuneStore.new(File.expand_path(SAVE_FILE))
    end
    return @@configloader_pstore
  end

  def self.create(prefix)
    Class.new{
      include ConfigLoader
      define_method(:configloader_key){ |key|
        "#{prefix}::#{key}" } }.new end

  # データが壊れていないかを調べる
  def self.boot
    if(FileTest.exist?(SAVE_FILE))
    SerialThread.new{
      c = create("valid")
      if not(c.at(:validate)) and FileTest.exist?(BACKUP_FILE)
        FileUtils.copy(BACKUP_FILE, SAVE_FILE)
        @@configloader_pstore = nil
        warn "database was broken. restore by backup"
      else
        FileUtils.install(SAVE_FILE, BACKUP_FILE)
      end
      c.store(:validate, true)
    }
    end
  end

  boot

end
