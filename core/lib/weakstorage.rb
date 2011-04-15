# -*- coding: utf-8 -*-
#
# Weak Storage
#

require 'set'
require 'thread'

class WeakStore
  def initialize
    @_storage = gen_storage
    @_mutex = Mutex.new end

  def atomic(&proc)
    @_mutex.synchronize(&proc) end

  protected

  def storage
    if(@_mutex.locked?)
      @_storage
    else
      raise "WeakStore inner storage can control in atomic{} block only."
      nil end end
end

class WeakStorage < WeakStore

  def [](key)
    begin
      atomic{
        ObjectSpace._id2ref(storage[key]) if storage.has_key?(key) }
    rescue RangeError => e
      @@bug = true
      error "#{key} was deleted"
      abort end end
  alias add []

  def []=(key, val)
    ObjectSpace.define_finalizer(val){ |objid| storage.delete(key) }
    atomic{
      storage[key] = val.object_id } end
  alias store []=

  def has_key?(key)
    atomic{
      storage.has_key?(key) } end

  private

  def gen_storage
    Hash.new end end

class WeakSet < WeakStore
  include Enumerable

  def each
    begin
      atomic{
        storage.each{ |n| yield(ObjectSpace._id2ref(n)) } }
    rescue RangeError => e
      error e
      nil end end

  def add(val)
    ObjectSpace.define_finalizer(val, &method(:on_delete))
    atomic{
      storage.add(val.object_id) } end
  alias << add

  private

  def gen_storage
    Set.new end

  def on_delete(objid)
    atomic{
      storage.delete(objid) } end

 end
