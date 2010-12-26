#
# ruby config loader
#

# オブジェクトにデータ保存機能を付与する

require File.expand_path('utils')
miquire :core, 'environment'

require 'fileutils'
require 'thread'

module ConfigLoader
  SAVE_FILE = "#{Environment::CONFROOT}p_class_values.db"

  @@configloader_pstore = nil
  @@configloader_cache = Hash.new

  def at(key, ifnone=nil)
    ckey = configloader_key(key)
    return @@configloader_cache[ckey] if @@configloader_cache.has_key?(ckey)
    ConfigLoader.transaction(true){
      if ConfigLoader.pstore.root?(ckey) then
        ConfigLoader.pstore[ckey].freeze
      elsif defined? yield then
        @@configloader_cache[ckey] = yield(key, ifnone).freeze
      else
        ifnone end } end

  def store(key, val)
    Thread.new{
      ConfigLoader.transaction{
        ConfigLoader.pstore[configloader_key(key)] = val } }
    if(val.frozen?)
      @@configloader_cache[configloader_key(key)] = val
    else
      @@configloader_cache[configloader_key(key)] = (val.clone.freeze rescue val) end end

  def store_before_at(key, val)
    result = self.at(key)
    self.store(key, val)
    return result || val
  end

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
end
