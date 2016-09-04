# -*- coding: utf-8 -*-

=begin rdoc
データの保存／復元を実際に担当するデータソース。
データソースをモデルにModel::add_data_retrieverにて幾つでも参加させることが出来る。
=end
module Retriever::DataSource
  USE_ALL = -1                  # findbyidの引数。全てのDataSourceから探索する
  USE_LOCAL_ONLY = -2           # findbyidの引数。ローカルにあるデータのみを使う

  attr_accessor :keys

  # idをもつデータを返す。
  # もし返せない場合は、nilを返す
  def findbyid(id, policy)
    nil
  end

  # 取得できたらそのRetrieverのインスタンスをキーにして実行されるDeferredを返す
  def idof(id)
    Thread.new{ findbyid(id) } end
  alias [] idof

  # データの保存
  # データ一件保存する。保存に成功したか否かを返す。
  def store_datum(datum)
    false
  end

  def inspect
    self.class.to_s
  end
end
