# -*- coding: utf-8 -*-

module Retriever
  # _model_slug_ をslugとして持つModelクラスを返す。
  # 見つからない場合、nilを返す。
  def self.Model(model_slug)
    model_slug = model_slug.to_sym
    ObjectSpace.each_object(Retriever::Model.singleton_class) do |klass|
      return klass if klass.slug == model_slug
    end
    nil
  end

  # _uri_ を Retriever::URI に変換する。
  # _uri_ が既に Retriever::URI のインスタンスだった場合は _uri_ を返すので、Retriever::URI
  # かもしれないオブジェクトを Retriever::URI に変換するのに使う。
  # ==== Args
  # 以下のいずれかのクラスのインスタンス。
  # [Retriever::URI] _uri_ をそのまま返す
  # [URI::Generic] Retriever::URI.new(uri) の結果を返す
  # [Addressable::URI] Retriever::URI.new(uri) の結果を返す
  # [String] _uri_ をURI文字列と見立てて、 URI::Generic または Addressable::URI に変換して、 Retriever::URI のインスタンスを作る
  # [Hash] _uri_ を URI::Generic または Addressable::URI コンストラクタに渡して、URIを作り、 Retriever::URI のインスタンスを作る
  # ==== Raises
  # [Retriever::InvalidURIError] _uri_ がURIではない場合
  def self.URI(uri)
    case uri
    when Retriever::URI
      uri
    when ::URI::Generic, Addressable::URI, String, Hash
      Retriever::URI.new(uri)
    end
  end

  def self.URI!(uri)
    self.URI(uri) or raise InvalidURIError, "`#{uri.class}' is not uri."
  end
end

require_relative 'retriever/cast'
require_relative 'retriever/datasource'
require_relative 'retriever/error'
require_relative 'retriever/model'
require_relative 'retriever/field_generator'
require_relative 'retriever/model/identity'
require_relative 'retriever/model/memory'
require_relative 'retriever/entity/blank_entity'
require_relative 'retriever/entity/regexp_entity'
require_relative 'retriever/entity/extended_twitter_entity'
require_relative 'retriever/entity/url_entity'
