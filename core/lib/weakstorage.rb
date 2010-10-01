#
# Weak Storage
#

require 'set'

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

class WeakSet
  include Enumerable

  def initialize
    @storage = Set.new end

  def each
    begin
      @storage.each{ |n| yield(ObjectSpace._id2ref(n)) }
    rescue RangeError => e
      error e
      nil end end

  def add(val)
    ObjectSpace.define_finalizer(val, &@storage.method(:delete))
    @storage.add(val.object_id) end
  alias << add

  def include?(key)
    !!@storage[key] end end
