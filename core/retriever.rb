# -*- coding: utf-8 -*-
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
    include Comparable

    @@storage = WeakStorage.new(Integer, Model) # id => <Model>

    def initialize(args)
      type_strict args => Hash
      @value = args.dup
      validate
      self.class.store_datum(self)
    end

    # 新しいオブジェクトを生成します
    # 既にそのカラムのインスタンスが存在すればそちらを返します
    # また、引数のハッシュ値はmergeされます。
    def self.generate(args, count=-1)
      return args if args.is_a?(self)
      return self.findbyid(args, count) if not(args.is_a? Hash)
      sresult = self.findbyid(args[:id], count)
      return result.merge(args) if result
      self.new(args)
    end

    def self.rewind(args)
      type_strict args => Hash
      result_strict(:merge){ new_ifnecessary(args) }.merge(args)
    end

    # まだそのレコードのインスタンスがない場合、それを生成して返します。
    def self.new_ifnecessary(hash)
      type_strict hash => tcor(self, Hash)
      result_strict(self) do
        if hash.is_a?(self)
          hash
        elsif hash[:id] and hash[:id] != 0
          atomic{
            @@storage[hash[:id].to_i] or self.new(hash) }
        else
          raise ArgumentError.new("incorrect type #{hash.class} #{hash.inspect}") end end end

    #
    # インスタンスメソッド
    #

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
        elsif not result.is_a?(Model)
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
          Model.cast(self.fetch(key), type, required)
        rescue InvalidTypeError=>e
          estr = e.to_s + "\nin #{self.fetch(key).inspect} of #{key}"
          warn estr
          warn @value.inspect
          raise InvalidTypeError, estr end } end

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
          raise InvalidTypeError, e.to_s + "\nin #{datum.inspect} of #{key}" end }
      result end

    #
    # クラスメソッド
    #

    # モデルのキーを定義します。
    # これを継承した実際のモデルから呼び出されることを想定しています
    def self.keys=(keys)
      @keys = keys end

    def self.keys
      @keys end

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
          return e.to_s + "\nin key '#{key}' value '#{src[key]}'" end }
      false end

    # DataSourceのチェーンに、 _retriever_ を登録します
    def self.add_data_retriever(retriever)
      retriever.keys = self.keys
      retrievers_add(retriever)
      retriever end

    # 特定のIDを持つオブジェクトを各データソースに問い合わせて返します。
    # 何れのデータソースもそれを見つけられなかった場合、nilを返します。
    def self.findbyid(id, count=-1)
      return findbyid_ary(id, count) if id.is_a? Array
      raise if(id.is_a? Model)
      it = (@findbyid ||= TimeLimitedStorage.new(Integer, Model))[id]
      # return it if it
      result = nil
      catch(:found){
        rs = self.retrievers
        count = rs.length + count + 1 if(count <= -1)
        rs = rs.slice(0, [count, 1].max)
        rs.each{ |retriever|
          detection = retriever.findbyid_timer(id)
          if detection
            result = detection
            throw :found end } }
      self.retrievers_reorder
      if result.is_a? Retriever::Model
        @findbyid[id] = result
      elsif result.is_a? Hash
        @findbyid[id] = self.new_ifnecessary(result) end
    rescue => e
      error e
      abort end

    def self.findbyid_ary(ids, count=-1)
      result = []
      remain = ids.clone
      ids.freeze
      catch(:found){
        rs = self.retrievers
        count = rs.length + count + 1 if(count <= -1)
        rs = rs.slice(0, [count, 1].max)
        rs.each{ |retriever|
          detection = retriever.findbyid_timer(remain)
          if detection
            detection = detection.select(&ret_nth).map(&method(:new_ifnecessary))
            result.concat(detection)
            remain -= detection.map{ |x| x[:id].to_i }
            throw :found if ids.empty? end } }
      self.retrievers_reorder
      result.sort_by{ |user| ids.index(user[:id].to_i) || 1.0/0 } end

    def self.selectby(key, value, count=-1)
      key = key.to_sym
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
        elsif node.is_a? Model
          node
        else
          self.findbyid(node) end } end

    #
    # プライベートクラスメソッド
    #

    # データを一件保存します。
    # 保存は、全てのデータソースに対して行われます
    def self.store_datum(datum)
      atomic{
        @@storage[datum[:id].to_i] = result_strict(self){ datum } }
      return datum if datum[:system]
      converted = datum.filtering
      self.retrievers.each{ |retriever|
        retriever.store_datum(converted) }
      datum
    end

    # 値を、そのカラムの型にキャストします。
    # キャスト出来ない場合はInvalidTypeError例外を投げます
    def self.cast(value, type, required=false)
      if value.nil?
        raise InvalidTypeError, 'it is required value'+[value, type, required].inspect if required
        nil
      elsif type.is_a?(Symbol)
        begin
          result = (value and Retriever::cast_func(type).call(value))
          if required and not result
            raise InvalidTypeError, 'it is required value, but returned nil from cast function' end
          result
        rescue InvalidTypeError
          raise InvalidTypeError, "#{value.inspect} is not #{type}" end
      elsif type.is_a?(Array)
        if value.respond_to?(:map)
          value.map{|v| cast(v, type.first, required)}
        elsif not value
          nil
        else
          raise InvalidTypeError, 'invalid type' end
      elsif value.is_a?(type)
        raise InvalidTypeError, 'invalid type' if required and not value.id
        value.id
      elsif self.cast(value, type.keys.assoc(:id)[1], true)
        value end end

    # メモリキャッシュオブジェクトを返す
    def self.memory_class
      Memory end

    # メモリキャッシュオブジェクトのインスタンス
    def self.memory
      @memory ||= memory_class.new(@@storage) end

    # DataSourceの配列を返します。
    def self.retrievers
      atomic{
        @retrievers = [memory] if not defined? @retrievers }
      @retrievers
    end

    def self.retrievers_add(retriever)
      self.retrievers << retriever end

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

    # 取得できたらそのRetrieverのインスタンスをキーにして実行されるDeferredを返す
    def idof(id)
      Thread.new{ findbyid(id) } end
    alias [] idof

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
      defined?(@time) ? @time : 0.0
    end

    def inspect
      self.class.to_s
    end
  end

  @@cast = {
    :int => lambda{ |v| begin v.to_i; rescue NoMethodError then raise InvalidTypeError end },
    :bool => lambda{ |v| !!(v and not v == 'false') },
    :string => lambda{ |v| begin v.to_s; rescue NoMethodError then raise InvalidTypeError end },
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

  class RetrieverError < StandardError
  end

  class InvalidTypeError < RetrieverError
  end

  class Model::Memory
    include Retriever::DataSource

    def initialize(storage)
      @storage = storage end

    # def children
    #   @children ||= Hash.new{ |h, k| h[k] = Set.new } end

    def findbyid(id)
      if id.is_a? Array or id.is_a? Set
        id.map{ |i| @storage[i.to_i] }
      else
        @storage[id.to_i] end
    end

    # def selectby(key, value)
    #   if key == :replyto
    #     children[value.to_i].to_a
    #   else
    #     [] end end

    # データの保存
    # def store_datum(datum)
    #   @storage[datum[:id]] = datum
    #   @children[datum[:replyto].to_i].push(datum[:id].to_i) if datum[:replyto]
    #   true
    # end
  end

end
