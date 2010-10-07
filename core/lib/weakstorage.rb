#
# Weak Storage
#

require 'set'

class WeakStorage
  attr_reader :on_delete

  def initialize
    @storage = Hash.new
    @on_delete = @storage.method(:delete).to_proc end

  def [](key)
    begin
      return ObjectSpace._id2ref(@storage[key]) if @storage[key]
    rescue RangeError => e
      puts "#{key} was deleted"
      @storage.delete(key)
      nil end end

  def []=(key, val)
    ObjectSpace.define_finalizer(val, &on_delete)
    @storage[key] = val.object_id end

  def has_key?(key)
    !!@storage[key] end end

class WeakSet
  include Enumerable
  attr_reader :on_delete

  def initialize
    @storage = Set.new
    @on_delete = @storage.method(:delete).to_proc end

  def each
    begin
      @storage.each{ |n| yield(ObjectSpace._id2ref(n)) }
    rescue RangeError => e
      error e
      nil end end

  def add(val)
    ObjectSpace.define_finalizer(val, &on_delete)
    @storage.add(val.object_id) end
  alias << add

  def include?(key)
    !!@storage[key] end end
