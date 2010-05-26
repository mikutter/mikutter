#
# Weak Storage
#

class WeakStorage
  def initialize
    @storage = Hash.new end

  def [](key)
    begin
      return ObjectSpace._id2ref(@storage[key]) if @storage[key]
    rescue RangeError => e
      puts "#{key} was deleted"
      @storage.delete(key)
      nil end end

  def []=(key, val)
    ObjectSpace.define_finalizer(val){ |id|
      @storage.delete(id) }
    @storage[key] = val.object_id end

  def has_key?(key)
    !!@storage[key] end end
