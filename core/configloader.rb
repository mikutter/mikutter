#
# ruby config loader
#

# オブジェクトにデータ保存機能を付与する

miquire :core, 'utils'

require 'fileutils'
require 'pstore'
require 'thread'

module ConfigLoader
  SAVE_FILE = "#{Environment::CONFROOT}p_class_values.db"

  @@configloader_pstore = nil
  @@configloader_mutex = Mutex.new
  @@configloader_cache = Hash.new

  def at(key, ifnone=nil)
    return @@configloader_cache[configloader_key(key)] if @@configloader_cache.has_key?(key)
    ConfigLoader.transaction(true){
      if ConfigLoader.pstore.root?(configloader_key(key)) then
        ConfigLoader.pstore[configloader_key(key)]
      elsif defined? yield then
        @@configloader_cache[configloader_key(key)] = yield(key, ifnone)
      else
        ifnone
      end
    }
  end

  def store(key, val)
    ConfigLoader.transaction{
      ConfigLoader.pstore[configloader_key(key)] = val
      @@configloader_cache[configloader_key(key)] = val
    }
  end

  def store_before_at(key, val)
    result = self.at(key)
    self.store(key, val)
    return result || val
  end

  def configloader_key(key)
    "#{self.class.to_s}::#{key}"
  end

  def self.transaction(ro = false)
    @@configloader_mutex.synchronize{
      result = self.pstore.transaction(ro){ |pstore|
        yield(pstore)
      }
      result
    }
  end

  def self.pstore
    if not(@@configloader_pstore) then
      FileUtils.mkdir_p(File.expand_path(File.dirname(SAVE_FILE)))
      @@configloader_pstore = PStore.new(File.expand_path(SAVE_FILE))
    end
    return @@configloader_pstore
  end

end
