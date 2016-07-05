# -*- coding: utf-8 -*-
=begin rdoc
  いろんなリソースの基底クラス
=end

miquire :lib, 'typed-array'

class Retriever::Model
  include Comparable

  class << self
    # def inherited(subclass)
    # end

    # 新しいオブジェクトを生成します
    # 既にそのカラムのインスタンスが存在すればそちらを返します
    # また、引数のハッシュ値はmergeされます。
    def generate(args)
      return args if args.is_a?(self)
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
        case hash
        when self
          hash
        when Hash
          self.new(hash)
        else
          raise ArgumentError.new("incorrect type #{hash.class} #{hash.inspect}") end end end

    # Modelのインスタンスのuriスキーム。オーバライドして適切な値にする
    # ==== Return
    # [String] URIスキーム
    memoize def scheme
      self.to_s.split('::',2).first.gsub(/\W/,'').downcase.freeze
    end

    # Modelのインスタンスのホスト名。オーバライドして適切な値にする
    # ==== Return
    # [String] ホスト名
    memoize def host
      self.to_s.split('::',2).last.split('::').reverse.join('.').gsub(/[^\w\.]/,'').downcase.freeze
    end

    # モデルのキーを定義します。
    # これを継承した実際のモデルから呼び出されることを想定しています
    def keys=(keys)
      @keys = keys
      keys.each do |name, type, required|
        if type.is_a? Symbol
          define_method(name) do
            @value[name]
          end
        else
          define_method(name) do
            if @value[name].is_a? Retriever::Model
              Delayer::Deferred.new{ @value[name] }
            else
              Thread.new{ type.findbyid(@value[name], Retriever::DataSource::USE_ALL) }
            end
          end

          define_method("#{name}!") do
            mainthread_only
            if @value[name].is_a? Retriever::Model
              @value[name]
            else
              type.findbyid(@value[name], Retriever::DataSource::USE_ALL)
            end
          end
        end

        define_method("#{name}?") do
          !!@value[name]
        end

        define_method("#{name}=") do |value|
          @value[key.to_sym] = value
          self.class.store_datum(self)
          value
        end
      end
      @keys
    end

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

    #
    # プライベートクラスメソッド
    #

    # Modelが生成・更新された時に呼ばれるコールバックメソッドです
    def store_datum(retriever); end

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
        value
      elsif self.cast(value, type.keys.assoc(:id)[1], true)
        value end end

    memoize def container_class
      TypedArray(Retriever::Model) end
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

  # このModelのパーマリンクを返す。
  # パーマリンクはWebのURLで、Web上のリソースでない場合はnilを返す。
  # ==== Return
  # 次のいずれか
  # [URI::HTTP] パーマリンク
  # [nil] パーマリンクが存在しない
  def perma_link
    nil
  end

  # このModelのURIを返す。
  # ==== Return
  # [URI::Generic] パーマリンク
  def uri
    perma_link || URI::Generic.new(self.class.scheme,nil,self.class.host,nil,nil,path,nil,nil,nil)
  end

  # このRetrieverが、登録されているアカウントのうちいずれかが作成したものであれば true を返す
  # ==== Args
  # [service] Service | Enumerable 「自分」のService
  # ==== Return
  # [true] 自分のによって作られたオブジェクトである
  # [false] 自分のによって作られたオブジェクトではない
  def me?(service=nil)
    false end

  def eql?(other)
    other.is_a?(self.class) and other.id == self.id end

  memoize def hash
    self.uri.to_s.hash ^ self.class.hash end

  def <=>(other)
    if other.is_a?(Retriever)
      id - other.id
    elsif other.respond_to?(:[]) and other[:id]
      id - other[:id]
    else
      id - other end end

  def ==(other)
    if other.is_a? Retriever::Model
      self.class == other.class && uri == other.uri
    end
  end

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
      elsif not result.is_a?(Retriever::Model::Identity)
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

  private
  # URIがデフォルトで使うpath要素
  def path
    @path ||= "/#{SecureRandom.uuid}"
  end

end

