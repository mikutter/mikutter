#
# Retriever
#

# 多カラムのデータの保存／復元／変更を隠蔽するモジュール
# ハッシュテーブルを保存し、後から検索できるようにする

miquire :lib, 'weakstorage'

module Retriever

  # モデルクラス。
  # と同時に、このクラスのインスタンスはレコードを表す
  class Model
    @@storage = WeakStorage.new # id => <Model>

    #
    # ジェネレータ
    #

    def initialize(args)
      @lock = Monitor.new
      @value = args
      validate
      self.class.store_datum(self)
    end

    # 新しいオブジェクトを生成します
    # 既にそのカラムのインスタンスが存在すればそちらを返します
    # また、引数のハッシュ値はmergeされます。
    def self.generate(args, count=-1)
      return args if args.is_a?(self)
      return self.findbyid(args, count) if not(args.is_a? Hash)
      result = self.findbyid(args[:id], count)
      return result.merge(args) if result
      self.new(args)
    end

    def self.rewind(args)
      new_ifnecessary(args).merge(args)
    end

    # まだそのレコードのインスタンスがない場合、それを生成して返します。
    def self.new_ifnecessary(hash)
      raise if not(hash[:id]) or hash[:id] == 0
      result = @@storage[hash[:id]]
      return result if result
      self.new(hash)
    end

    #
    # インスタンスメソッド
    #

    # データをマージする。
    # selfにあってotherにもあるカラムはotherの内容で上書きされる。
    # 上書き後、データはDataSourceに保存される
    def merge(other)
      @lock.synchronize{
        @value.update(other.to_hash) }
      validate
      self.class.store_datum(self)
    end

    def id
      @value[:id]
    end

    def to_hash
      @value
    end

    # カラムの生の内容を返す
    def fetch(key)
      @value[key.to_sym]
    end

    # 速い順にcount個のRetrieverだけに問い合わせて返します
    def get(key, count=1)
      result = @value[key.to_sym]
      column = self.class.keys.assoc(key.to_sym)
      if column and result then
        type = column[1]
        if type.is_a? Symbol then
          Retriever::cast_func(type).call(result)
        elsif not result.is_a?(Model) then
          result = type.findbyid(result, count)
          if result
            return @lock.synchronize{ @value[key.to_sym] = result } end end end
      result end

    # カラムの内容を取得する
    # カラムに入っているデータが外部キーであった場合、それを一段階だけ求めて返す
    def [](key)
      fetch(key)
    end

    # カラムに別の値を格納する。
    # 格納後、データはDataSourceに保存される
    def []=(key, value)
      @lock.synchronize{
        @value[key.to_sym] = value }
      self.class.store_datum(self)
      value
    end

    # カラムと型が違うものがある場合、例外を発生させる。
    def validate
      raise RuntimeError, "argument is #{@value}, not Hash" if not @value.is_a?(Hash)
      self.class.keys.each{ |column|
        key, type, required = *column
        begin
          Model.cast(self.fetch(key), type, required)
        rescue InvalidTypeError=>e
          warn e.to_s + "\nin #{self.fetch(key).inspect} of #{key}"
          warn @value.inspect
          raise InvalidTypeError, e.to_s + "\nin #{self.fetch(key).inspect} of #{key}"
        end
      }
    end


    # キーとして定義されていない値を全て除外した配列を生成して返す。
    # また、Modelを子に含んでいる場合、それを外部キーに変換する。
    def filtering
      datum = self.to_hash
      result = Hash.new
      self.class.keys.each{ |column|
        key, type = *column
        begin
          result[key] = Model.cast(datum[key], type)
        rescue InvalidTypeError=>e
          raise InvalidTypeError, e.to_s + "\nin #{datum.inspect} of #{key}"
        end
      }
      result
    end

    #
    # クラスメソッド
    #

    # モデルのキーを定義します。
    # これを継承した実際のモデルから呼び出されることを想定しています
    def self.keys=(keys)
      @keys = keys
    end

    def self.keys
      @keys
    end

    # srcが正常にModel化できるかどうかを返します。
    def self.valid?(src)
      return src.is_a?(self) if not src.is_a?(Hash)
      not self.get_error(src) end

    # srcがModel化できない理由を返します。
    def self.get_error(src)
      self.keys.each{ |column|
        key, type, required = *column
        begin
          Model.cast(src[key], type, required)
        rescue InvalidTypeError=>e
          return e.to_s + "\nin key '#{key}' value '#{src[key]}'"
        end }
      false end

    # DataSourceを登録します
    def self.add_data_retriever(retriever)
      retriever.keys = self.keys
      retrievers_add(retriever)
      retriever
    end

    # 特定のIDを持つオブジェクトを各データソースに問い合わせて返します。
    # 何れのデータソースもそれを見つけられなかった場合、nilを返します。
    def self.findbyid(id, count=-1)
      # return @@storage[hash[:id]] if @@storage.has_key?(hash[:id])
      result = nil
      catch(:found){
        rs = self.retrievers
        count = rs.length + count + 1 if(count <= -1)
        rs = rs.slice(0, [count, 1].max)
        rs.each{ |retriever|
          detection = retriever.findbyid_timer(id)
          notice retriever.class.to_s + ": " + detection.class.to_s
          if detection
            result = detection
            throw :found end } }
        self.retrievers_reorder
        self.new_ifnecessary(result) if result end

    def self.selectby(key, value, count=-1)
      key = key.to_sym
      # return @@storage[hash[key]] if @@storage.has_key?(hash[key])
      result = []
      rs = self.retrievers
      count = rs.length + count + 1 if(count <= -1)
      rs = rs.slice(0, [count, 1].max)
      rs.each{ |retriever|
        detection = retriever.selectby_timer(key, value)
        result += detection if detection }
      self.retrievers_reorder
      result.uniq.map{ |node|
        if node.is_a? Hash
          self.new_ifnecessary(node)
        else
          self.findbyid(node) end } end

    #
    # プライベートクラスメソッド
    #

    # データを一件保存します。
    # 保存は、全てのデータソースに対して行われます
    def self.store_datum(datum)
      return datum if datum[:system]
      converted = datum.filtering
      self.retrievers.each{ |retriever|
        retriever.store_datum(converted) }
      @@storage[datum[:id]] = datum
      datum
    end

    # 値を、そのカラムの型にキャストします。
    # キャスト出来ない場合はInvalidTypeError例外を投げます
    def self.cast(value, type, required=false)
      if not value
        raise InvalidTypeError, 'it is required value' if required
      elsif type.is_a?(Symbol) then
        begin
          result = (value and Retriever::cast_func(type).call(value))
          if required and not result
            raise InvalidTypeError, 'it is required value, but returned nil from cast function' end
          result
        rescue InvalidTypeError=>e
          raise InvalidTypeError, "#{value.inspect} is not #{type}" end
      elsif value.is_a?(type)
        raise InvalidTypeError, 'invalid type' if required and not value.id
        value.id
      elsif self.cast(value, type.keys.assoc(:id)[1], true)
        value end end

    # DataSourceの配列を返します。
    def self.retrievers
      atomic{
        @retrievers = [Memory.new] if not defined? @retrievers }
      @retrievers
    end

    def self.retrievers_add(retriever)
      atomic{
        self.retrievers << retriever }
      raise RuntimeError if not self.retrievers.include?(retriever)
    end

    #DataSourceの配列を、最後の取得が早かった順番に並び替えます
    def self.retrievers_reorder
      atomic{
        @retrievers = self.retrievers.sort_by{ |r| r.time } }
    end

  end

  # データの保存／復元を実際に担当するデータソース。
  # データソースをモデルにModel::add_data_retrieverにて幾つでも参加させることが出来る。
  module DataSource
    attr_accessor :keys

    # idをもつデータを返す。
    # もし返せない場合は、nilを返す
    def findbyid(id)
      nil
    end

    # keyがvalueのオブジェクトを配列で返す。
    # マッチしない場合は空の配列を返す。Arrayオブジェクト以外は返してはならない。
    def selectby(key, value)
      []
    end

    # データの保存
    # データ一件保存する。保存に成功したか否かを返す。
    def store_datum(datum)
      false
    end

    def findbyid_timer(id)
      st = Process.times.utime
      result = findbyid(id)
      @time = Process.times.utime - st if result
      result
    end

    def selectby_timer(key, value)
      st = Process.times.utime
      result = selectby(key, value)
      @time = Process.times.utime - st if not result.empty?
      result
    end

    def time
      @time or 0.0
    end

    def inspect
      self.class.to_s
    end
  end

  @@cast = {
    :int => lambda{ |v| begin v.to_i; rescue NoMethodError=>e then raise InvalidTypeError end },
    :bool => lambda{ |v| !!(v and not v == 'false') },
    :string => lambda{ |v| begin v.to_s; rescue NoMethodError=>e then raise InvalidTypeError end },
    :time => lambda{ |v|
      if not v then
        nil
      elsif v.is_a? String then
        Time.parse(v)
      else
        Time.at(v)
      end
    }
  }

  def self.cast_func(type)
    @@cast[type]
  end

  class InvalidTypeError < Exception
  end

  class Model::Memory
    include Retriever::DataSource

    def initialize
      @storage = Hash.new
      @children = Hash.new{ [] }
    end

    def findbyid(id)
      @storage[id]
    end

    def selectby(key, value)
      if key == :replyto
        @children[value.to_i]
      else
        [] end end

    # データの保存
    def store_datum(datum)
      @storage[datum[:id]] = datum
      @children[datum[:replyto]] = @children[datum[:replyto]].push(datum[:id])  if datum[:replyto]
      true
    end
  end

end
