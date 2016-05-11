# -*- coding: utf-8 -*-

=begin rdoc
データの保存／復元を実際に担当するデータソース。
データソースをモデルにModel::add_data_retrieverにて幾つでも参加させることが出来る。
=end
module Retriever::DataSource
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
