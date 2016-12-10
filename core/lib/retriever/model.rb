# -*- coding: utf-8 -*-
=begin rdoc
  いろんなリソースの基底クラス
=end

miquire :lib, 'typed-array'

require_relative 'uri'

class Retriever::Model
  include Comparable

  class << self
    extend Gem::Deprecate

    attr_reader :slug, :spec

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

    # Modelにフィールド _field_name_ を追加する。
    # ==== Args
    # [field_name] Symbol フィールドの名前
    # [type] Symbol フィールドのタイプ。:int, :string, :bool, :time のほか、Retriever::Modelのサブクラスを指定する
    # [required] boolean _true_ なら、この項目を必須とする
    def add_field(field_name, type:, required: false)
      (@keys ||= []) << [field_name, type, required]
      if type.is_a? Symbol
        define_method(field_name) do
          @value[field_name]
        end
      else
        define_method(field_name) do
          if @value[field_name].is_a? Retriever::Model
            @value[field_name]
          end
        end

        define_method("#{field_name}!") do
          mainthread_only
          if @value[field_name].is_a? Retriever::Model
            @value[field_name]
          else
            type.findbyid(@value[field_name], Retriever::DataSource::USE_ALL)
          end
        end
      end

      define_method("#{field_name}?") do
        !!@value[field_name]
      end

      define_method("#{field_name}=") do |value|
        @value[field_name] = Retriever::Model.cast(value, type, required)
        self.class.store_datum(self)
        value
      end
      self
    end

    def keys
      @keys end

    # Entityクラスを設定する。
    # ==== Args
    # [klass] Class 新しく設定するEntityクラス
    # ==== Return
    # [Class] セットされた（されている）Entityクラス
    def entity_class(klass=nil)
      if klass
        @entity_class = klass
      else
        @entity_class ||= Retriever::Entity::BlankEntity
      end
    end

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

    # Modelの情報を設定する。
    # このメソッドを呼ぶと、他のプラグインがこのRetrieverを見つけることができるようになるので、
    # 抽出タブの抽出条件が追加されたり、設定で背景色が指定できるようになる
    # ==== Args
    # [new_slug] Symbol
    # [name:] String Modelの名前
    # [reply:] bool このRetrieverに、宛先が存在するなら真
    # [myself:] bool このRetrieverを、自分のアカウントによって作成できるなら真
    def register(new_slug,
                 name: new_slug.to_s,
                 reply: true,
                 myself: true
                )
      @slug = new_slug.to_sym
      spec = @spec = {slug: @slug,
                      name: name.to_s.freeze,
                      reply: !!reply,
                      myself: !!myself
                     }.freeze
      plugin do
        filter_retrievers do |retrievers|
          retrievers << spec
          [retrievers]
        end
      end
    end

    def field
      Retriever::FieldGenerator.new(self)
    end

    # あるURIが、このModelを示すものであれば真を返す条件 _condition_ を設定する。
    # _condition_ === uri が実行され、真を返せばそのURIをこのModelで取り扱えるということになる
    # ==== Args
    # [condition] 正規表現など、URIにマッチするもの
    # ==== Return
    # self
    # ==== Block
    # 実際にURIが指し示すリソースの内容を含んだModelを作って返す
    # ===== Args
    # [uri] URI マッチしたURI
    # ===== Return
    # [Delayer::Deferred::Deferredable]
    #   ネットワークアクセスを行って取得するなど取得に時間がかかる場合
    # [self]
    #   すぐにModelを生成できる場合、そのModel
    # ===== Raise
    # [Retriever::ModelNotFoundError] _uri_ に対応するリソースが見つからなかった
    def handle(condition)       # :yield: uri
      model_slug = self.slug
      plugin do
        if condition.is_a? Regexp
          filter_model_of_uri do |uri, models|
            if condition =~ uri.to_s
              models << model_slug
            end
            [uri, models]
          end
        else
          filter_model_of_uri do |uri, models|
            if condition === uri
              models << model_slug
            end
            [uri, models]
          end
        end
      end
      if block_given?
        class << self
          define_method(:find_by_uri, Proc.new)
        end
      end
    end

    # URIに対応するリソースの内容を持ったModelを作成する。
    # URIに対応する情報はネットワーク上などから取得される場合もある。そういった場合はこのメソッドは
    # Delayer::Deferred::Deferredable を返す可能性がある。
    # このメソッドの振る舞いを変更したい場合は、 _handle_ メソッドを利用する。
    # ==== Args
    # [uri] _handle_ メソッドで指定したいずれかの条件に一致するURI
    # ==== Return
    # [Delayer::Deferred::Deferredable]
    #   ネットワークアクセスを行って取得するなど取得に時間がかかる場合
    # [self]
    #   すぐにModelを生成できる場合、そのModel
    # ==== Raise
    # [Retriever::NotImplementedError] _handle_ メソッドを一度もブロック付きで呼び出しておらず、Modelを取得できない
    # [Retriever::ModelNotFoundError] _uri_ に対応するリソースが見つからなかった
    def find_by_uri(uri)
      raise Retriever::NotImplementedError, "#{self}.find_by_uri does not implement."
    end

    def plugin
      if not @slug
        raise Retriever::RetrieverError, "`#{self}'.slug is not set."
      end
      if block_given?
        Plugin.create(:"retriever_model_#{@slug}", &Proc.new)
      else
        Plugin.create(:"retriever_model_#{@slug}")
      end
    end

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

  # Entityのリストを返す。
  # ==== Return
  # Retriever::Entity::BlankEntity
  def links
    @entity ||= self.class.entity_class.new(self)
  end
  alias :entity :links

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
  # [URI::Generic|Retriever::URI] パーマリンク
  def uri
    perma_link || Retriever::URI.new("#{self.class.scheme}://#{self.class.host}#{path}")
  end

  # このRetrieverが、登録されているアカウントのうちいずれかが作成したものであれば true を返す
  # ==== Args
  # [service] Service | Enumerable 「自分」のService
  # ==== Return
  # [true] 自分のによって作られたオブジェクトである
  # [false] 自分のによって作られたオブジェクトではない
  def me?(service=nil)
    false end

  memoize def hash
    self.uri.to_s.hash ^ self.class.hash end

  def <=>(other)
    if other.is_a?(Retriever::Model)
      created - other.created
    elsif other.respond_to?(:[]) and other[:created]
      created - other[:created]
    else
      id - other end end

  def ==(other)
    if other.is_a? Retriever::Model
      self.class == other.class && uri == other.uri
    end
  end

  def eql?(other)
    self == other
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
        @value[key.to_sym] = Retriever::Model.cast(self.fetch(key), type, required)
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

