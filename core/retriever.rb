#
# Retriever
#

# 多カラムのデータの保存／復元／変更を隠蔽するモジュール
# ハッシュテーブルを保存し、後から検索できるようにする

module Retriever

  # モデルクラス。
  # と同時に、このクラスのインスタンスはレコードを表す
  class Model
    @@storage = Hash.new # id => <Model>
    @@class_lock = Monitor.new

    #
    # インスタンスメソッド
    #

    def initialize(args)
      @value = args
      @instance_lock = Monitor.new
      validate
      self.class.store_datum(self)
    end

    # データをマージする。
    # selfにあってotherにもあるカラムはotherの内容で上書きされる。
    # 上書き後、データはDataSourceに保存される
    def merge(other)
      @instance_lock.synchronize{
        @value.update(other.to_hash)
        self.class.store_datum(self)
      }
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

    # カラムの内容を取得する
    # カラムに入っているデータが外部キーであった場合、それを一段階だけ求めて返す
    def [](key)
      @instance_lock.synchronize{
        result = @value[key.to_sym]
        column = self.class.keys.assoc(key.to_sym)
        if column and result then
          type = column[1]
          if type.is_a? Symbol then
            Retriever::cast_func(type).call(result)
          elsif not result.is_a?(Model) then
            result = type.generate(result)
            return @value[key.to_sym] = result if result
          end
        end
        result
      }
    end

    # カラムに別の値を格納する。
    # 格納後、データはDataSourceに保存される
    def []=(key, value)
      @instance_lock.synchronize{
        @value[key.to_sym] = value
        self.class.store_datum(self)
      }
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

    # 新しいオブジェクトを生成します
    # 既にそのカラムのインスタンスが存在すればそちらを返します
    # また、引数のハッシュ値はmergeされます。
    def self.generate(args)
      return args if args.is_a?(self)
      return self.findbyid(args) if not(args.is_a? Hash)
      result = self.findbyid(args[:id])
      return result.merge(args) if result
      self.new(args)
    end

    # srcが正常にModel化できるかどうかを返します。
    def self.valid?(src)
      return src.is_a?(self) if not src.is_a?(Hash)
      self.keys.each{ |column|
        key, type, required = *column
        begin
          Model.cast(src[key], type, required)
        rescue InvalidTypeError=>e
          return false
        end
      }
      true
    end

    # DataSourceを登録します
    def self.add_data_retriever(retriever)
      retriever.keys = self.keys
      retrievers_add(retriever)
      retriever
    end

    # 特定のIDを持つオブジェクトを各データソースに問い合わせて返します。
    # 何れのデータソースもそれを見つけられなかった場合、nilを返します。
    def self.findbyid(id)
      return @@storage[hash[:id]] if @@storage.has_key?(hash[:id])
      @@class_lock.synchronize{
        result = catch(:found){
          self.retrievers.each{ |retriever|
            detection = retriever.findbyid_timer(id)
            throw :found, detection if self.valid?(detection)
          }
          throw :found, nil
        }
        self.retrievers_reorder
        return self.new_ifnecessary(result) if result
      }
      nil
    end

    #
    # プライベートクラスメソッド
    #

    # データを一件保存します。
    # 保存は、全てのデータソースに対して行われます
    def self.store_datum(datum)
      converted = datum.filtering
      @@class_lock.synchronize{
        self.retrievers.each{ |retriever|
          retriever.store_datum(converted)
        }
      }
      @@storage[datum[:id]] = datum
      datum
    end

    # 値を、そのカラムの型にキャストします。
    # キャスト出来ない場合はInvalidTypeError例外を投げます
    def self.cast(value, type, required=false)
      if not value then
        if required then
          raise InvalidTypeError, 'it is required value'
        end
      elsif type.is_a?(Symbol) then
        begin
          result = (value and Retriever::cast_func(type).call(value))
          if required and not result then
            raise InvalidTypeError, 'it is required value'
          end
          return result
        rescue InvalidTypeError=>e
          raise InvalidTypeError, "#{value.inspect} is not #{type}"
        end
      elsif value.is_a?(type)
        if required and not value.id then
          raise InvalidTypeError, 'it is required value'
        end
        value.id
      elsif self.cast(value, type.keys.assoc(:id)[1], true)
        value
      end
    end

    # DataSourceの配列を返します。
    def self.retrievers
      @@class_lock.synchronize{
        @retrievers = [Retriever::Memory.new] if not defined? @retrievers
      }
      @retrievers
    end

    def self.retrievers_add(retriever)
      @@class_lock.synchronize{
        self.retrievers << retriever
      }
      raise RuntimeError if not self.retrievers.include?(retriever)
    end

    #DataSourceの配列を、最後の取得が早かった順番に並び替えます
    def self.retrievers_reorder
      @@class_lock.synchronize{
        @retrievers = self.retrievers.sort_by{ |r| r.time }
      }
    end

    # まだそのレコードのインスタンスがない場合、それを生成して返します。
    def self.new_ifnecessary(hash)
      @@class_lock.synchronize{
        result = @@storage[hash[:id]]
        return result if result
        self.new(hash)
      }
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

    # データの保存
    # データ一件保存する。保存に成功したか否かを返す。
    def store_datum(datum)
      false
    end

    def findbyid_timer(id)
      st = Process.times.utime
      result = findbyid(id)
      @time = Process.times.utime - st
      result
    end

    def time
      @time or 0.0
    end

  end

  class Memory
    include DataSource

    def initialize
      @storage = Hash.new
    end

    def findbyid(id)
      @storage[id]
    end

    # データの保存
    def store_datum(datum)
      @storage[datum[:id]] = datum
      true
    end
  end

  @@cast = {
    :int => lambda{ |v| begin v.to_i; rescue NoMethodError=>e then raise InvalidTypeError end },
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

end

if __FILE__ == $0 then
  class Message < Retriever::Model
    self.keys = [[:id, :int, :required],
                 [:title, :string],
                 [:desc, :string],
                 [:replyto, Message, true],
                 [:created, :time]]
  end

  p a = Message.generate(:id => 1, :title => 'hello')
end
