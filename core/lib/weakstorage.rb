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
    @_mutex = Monitor.new
    @_tls_name = "weakstore_lock_#{@_mutex.object_id}".to_sym
    @exit = false end

  def atomic(&proc)
    if not exit
      Thread.current[@_tls_name] ||= 0
      Thread.current[@_tls_name] += 1
      begin
        @_mutex.synchronize(&proc)
      ensure
        Thread.current[@_tls_name] -= 1 end end end

  protected

  def storage
    if(Thread.current[@_tls_name] and Thread.current[@_tls_name] >= 1)
      @_storage
    else
      raise "WeakStore inner storage can control in atomic{} block only. #{Thread.current[@_tls_name]}"
      nil end end
end

# 一定時間以上参照されなかったデータを自動的に忘れていく連想配列っぽいもの。
# デフォルトの最低有効期限(expire)は1800秒(30分)。expireより長くオブジェクトが保持される可能性がある。
class TimeLimitedStorage < WeakStore

  def initialize(key_class=Object, val_class=Object, expire = 1800)
    @key_class, @val_class, @expire, @repository, @last_modified = key_class, val_class, expire, gen_storage, Time.new.freeze
    super()
  end

  def [](key)
    atomic{
      result = if storage.has_key?(key)
                 storage[key]
               elsif @repository.has_key?(key)
                 @_storage[key] = @repository[key] end
      repository
      result } end
  alias get []

  def []=(key, val)
    type_strict key => @key_class, val => @val_class
    atomic{
      storage[key] = val
      @repository.delete(key) if(@repository.has_key?(key))
      repository }
  end
  alias store []=

  def has_key?(key)
    atomic{
      result = if storage.has_key?(key)
                 true
               elsif @repository.has_key?(key)
                 @_storage[key] = @repository[key]
                 true end
      repository
      result } end

  def inspect
    atomic{ "#<TimeLimitedStorage(#{@key_class} => #{@val_class}): #{storage.size}>" }
  end

  private
  def repository
    now = Time.new
    if (@last_modified + @expire) < now
      @last_modified = now.freeze
      @repository = @_storage
      @_storage = gen_storage end end

  def gen_storage
    Hash.new end

end

# ストレージ内の要素が一定のサイズ以上になったら、古いものから消去される連想配列っぽいもの。
class SizeLimitedStorage < WeakStore
  # 格納できる容量
  attr_accessor :limit

  # 使用している容量
  attr_reader :using

  # ==== Args
  # [limit] 格納できる容量(Integer)
  # [&proc] 要素の容量を返すブロック(デフォルト: sizeメソッド)
  def initialize(key_class, val_class, limit, proc=(block_given? ? Proc.new : :size.to_proc))
    @key_class, @val_class, @limit, @get_size = key_class, val_class, limit, proc
    @using = 0
    super()
  end

  def [](key)
    atomic { storage[key] } end
  alias get []

  # 値 _val_ を追加する。
  # これを入れることで容量制限を超えてしまう場合、入るようになるまで古い要素から順番に破棄される。
  # _val_ のサイズが 容量制限以上だったら追加されない。
  # ==== Args
  # [key] キー
  # [val] 値
  # ==== Return
  # val 又は nil（値が大きすぎて格納できない場合）
  def []=(key, val)
    type_strict key => @key_class, val => @val_class
    val_size = get_size(val.freeze)
    return nil if val_size >= @limit
    atomic {
      delete key
      insert_value(key, val, val_size) }
    val
  end
  alias store []=

  def has_key?(key)
    atomic{ storage.has_key? key }
  end

  # _key_ に対応する値を削除する
  # ==== Args
  # [key] キー
  # ==== Return
  # 削除した値。値が存在しない場合はnil。
  def delete(key)
    type_strict key => @key_class
    atomic {
      if has_key? key
        result = storage.delete(key)
        @using -= get_size(result)
        result end } end

  def inspect
    "#<SizeLimitedStorage(#{@using}/#{@limit})>" end

  private
  def get_size(obj)
    type_strict obj => @val_class
    @get_size.call(obj) end

  def insert_value(key, val, val_size = get_size(val))
    type_strict key => @key_class, val => @val_class
    if (@using + val_size) <= @limit
      @using += val_size
      storage[key] = val
    else
      delete storage.first[0]
      insert_value(key, val, val_size) end end

  def gen_storage
    Hash.new end end

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
