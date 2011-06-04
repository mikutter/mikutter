# -*- coding: utf-8 -*-
#
# Weak Storage
#

require 'set'
require 'thread'

END{
  ObjectSpace.each_object(WeakStore){ |s|
    s.exit = true
  }
}

class WeakStore
  attr_accessor :exit

  def initialize
    @_storage = gen_storage
    @_mutex = Mutex.new
    @exit = false end

  def atomic(&proc)
    @_mutex.synchronize(&proc) if not exit end

  protected

  def storage
    if(@_mutex.locked?)
      @_storage
    else
      raise "WeakStore inner storage can control in atomic{} block only."
      nil end end
end

class WeakStorage < WeakStore

  def initialize(key_class, val_class)
    @key_class, @val_class = key_class, val_class
    super()
  end

  def [](key)
    begin
      result = atomic{
        ObjectSpace._id2ref(storage[key]) if storage.has_key?(key) }
      type_strict result => @val_class if result
      result
    rescue RangeError => e
      error "#{key} was deleted"
      nil end end
  alias add []

  def []=(key, val)
    type_strict key => @key_class, val => @val_class
    ObjectSpace.define_finalizer(val, &gen_deleter)
    atomic{
      storage[key] = val.object_id } end
  alias store []=

  def has_key?(key)
    atomic{
      storage.has_key?(key) } end

  def inspect
    atomic{ "#<WeakStorage(#{@key_class} => #{@val_class}): #{storage.size}>" }
  end

  private

  def gen_deleter
    @deleter ||= lambda{ |objid| atomic{ storage.delete_if{ |key, val| val == objid } } }
  end

  def gen_storage
    Hash.new end end

class WeakSet < WeakStore
  include Enumerable

  def initialize(val_class)
    @val_class = val_class
    super()
  end

  def each
    begin
      atomic{
        storage.each{ |n| yield(ObjectSpace._id2ref(n)) } }
    rescue RangeError => e
      error e
      nil end end

  def add(val)
    type_strict val => @val_class
    ObjectSpace.define_finalizer(val, &gen_deleter)
    atomic{
      storage.add(val.object_id) } end
  alias << add

  def inspect
    atomic{ "#<WeakSet(#{@val_class}): #{storage.size}>" }
  end

  private

  def gen_storage
    Set.new end

  def gen_deleter
    @gen_deleter ||= lambda{ |objid|
      atomic{
        storage.delete(objid) } } end

 end
