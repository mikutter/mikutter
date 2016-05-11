# -*- coding: utf-8 -*-
=begin rdoc
  いろんなリソースの基底クラス
=end
class Retriever::Model
  include Comparable

  class << self
    # def inherited(subclass)
    # end

    # 新しいオブジェクトを生成します
    # 既にそのカラムのインスタンスが存在すればそちらを返します
    # また、引数のハッシュ値はmergeされます。
    def generate(args, policy=Retriever::DataSource::USE_ALL)
      return args if args.is_a?(self)
      return self.findbyid(args, policy) if not(args.is_a? Hash)
      result = self.findbyid(args[:id], policy)
      return result.merge(args) if result
      self.new(args)
    end

    def rewind(args)
      type_strict args => Hash
      result_strict(:merge){ new_ifnecessary(args) }.merge(args)
    end

    # まだそのレコードのインスタンスがない場合、それを生成して返します。
    def new_ifnecessary(hash)
      type_strict hash => tcor(self, Hash)
      result_strict(self) do
        if hash.is_a?(self)
          hash
        elsif hash[:id] and hash[:id] != 0
          atomic{
            memory.findbyid(hash[:id].to_i, Retriever::DataSource::USE_LOCAL_ONLY) or self.new(hash) }
        else
          raise ArgumentError.new("incorrect type #{hash.class} #{hash.inspect}") end end end

    # モデルのキーを定義します。
    # これを継承した実際のモデルから呼び出されることを想定しています
    def keys=(keys)
      @keys = keys end

    def keys
      @keys end

    # srcが正常にModel化できるかどうかを返します。
    def valid?(src)
      return src.is_a?(self) if not src.is_a?(Hash)
      not self.get_error(src) end

    # srcがModel化できない理由を返します。
    def get_error(src)
      self.keys.each{ |column|
        key, type, required = *column
        begin
          Retriever::Model.cast(src[key], type, required)
        rescue Retriever::InvalidTypeError=>e
          return e.to_s + "\nin key '#{key}' value '#{src[key]}'" end }
      false end

    def memory
      @memory ||= Retriever::Model::Memory.new(self) end

    # idキーが _id_ のインスタンスを返す。
    # ==== Args
    # [id] Integer|Enumerable 検索するIDか、IDを列挙するEnumerable
    # ==== Return
    # 次のいずれか
    # [nil] その条件で見つけられなかった場合
    # [Retriever] 見つかった場合
    # [Enumerable] _id_ にEnumerableを渡した場合。列挙される順番は、　_id_　の順番どおり。
    def findbyid(id, policy=Retriever::DataSource::USE_ALL)
      memory.findbyid(id, policy) end

    #
    # プライベートクラスメソッド
    #

    # データを一件保存します。
    # 保存は、全てのデータソースに対して行われます
    def store_datum(datum)
      memory.store_datum(datum) end

    # 値を、そのカラムの型にキャストします。
    # キャスト出来ない場合はInvalidTypeError例外を投げます
    def cast(value, type, required=false)
      if value.nil?
        raise Retriever::InvalidTypeError, 'it is required value'+[value, type, required].inspect if required
        nil
      elsif type.is_a?(Symbol)
        begin
          result = (value and Retriever::cast_func(type).call(value))
          if required and not result
            raise Retriever::InvalidTypeError, 'it is required value, but returned nil from cast function' end
          result
        rescue Retriever::InvalidTypeError
          raise Retriever::InvalidTypeError, "#{value.inspect} is not #{type}" end
      elsif type.is_a?(Array)
        if value.respond_to?(:map)
          value.map{|v| cast(v, type.first, required)}
        elsif not value
          nil
        else
          raise Retriever::InvalidTypeError, 'invalid type' end
      elsif value.is_a?(type)
        raise Retriever::InvalidTypeError, 'invalid type' if required and not value.id
        value.id
      elsif self.cast(value, type.keys.assoc(:id)[1], true)
        value end end

    def container_class
      Array end
  end

  def initialize(args)
    type_strict args => Hash
    @value = args.dup
    validate
    self.class.store_datum(self)
  end

  # データをマージする。
  # selfにあってotherにもあるカラムはotherの内容で上書きされる。
  # 上書き後、データはDataSourceに保存される
  def merge(other)
    @value.update(other.to_hash)
    validate
    self.class.store_datum(self)
  end

  def id
    @value[:id]
  end

  def eql?(other)
    other.is_a?(self.class) and other.id == self.id end

  def hash
    self.id.to_i end

  def <=>(other)
    if other.is_a?(Retriever)
      id - other.id
    elsif other.respond_to?(:[]) and other[:id]
      id - other[:id]
    else
      id - other end end

  def ==(other)
    if other.is_a?(Retriever)
      id == other.id
    elsif other.respond_to?(:[]) and other[:id]
      id == other[:id]
    else
      id == other end end

  def to_hash
    @value.dup
  end

  # カラムの生の内容を返す
  def fetch(key)
    @value[key.to_sym] end
  alias [] fetch

  # 速い順にcount個のRetrieverだけに問い合わせて返す
  def get(key, count=1)
    result = @value[key.to_sym]
    column = self.class.keys.assoc(key.to_sym)
    if column and result
      type = column[1]
      if type.is_a? Symbol
        Retriever::cast_func(type).call(result)
      elsif not result.is_a?(Retriever::Model)
        result = type.findbyid(result, count)
        if result
          return @value[key.to_sym] = result end end end
    result end


  # カラムに別の値を格納する。
  # 格納後、データはDataSourceに保存される
  def []=(key, value)
    @value[key.to_sym] = value
    self.class.store_datum(self)
    value end

  # カラムと型が違うものがある場合、例外を発生させる。
  def validate
    raise RuntimeError, "argument is #{@value}, not Hash" if not @value.is_a?(Hash)
    self.class.keys.each{ |column|
      key, type, required = *column
      begin
        Retriever::Model.cast(self.fetch(key), type, required)
      rescue Retriever::InvalidTypeError=>e
        estr = e.to_s + "\nin #{self.fetch(key).inspect} of #{key}"
        warn estr
        warn @value.inspect
        raise Retriever::InvalidTypeError, estr end } end

  # キーとして定義されていない値を全て除外した配列を生成して返す。
  # また、Modelを子に含んでいる場合、それを外部キーに変換する。
  def filtering
    datum = self.to_hash
    result = Hash.new
    self.class.keys.each{ |column|
      key, type = *column
      begin
        result[key] = Retriever::Model.cast(datum[key], type)
      rescue Retriever::InvalidTypeError=>e
        raise Retriever::InvalidTypeError, e.to_s + "\nin #{datum.inspect} of #{key}" end }
    result end
end
