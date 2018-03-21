# -*- coding: utf-8 -*-
require 'diva'

Retriever = Diva

module Diva
  # _model_slug_ をslugとして持つModelクラスを返す。
  # 見つからない場合、nilを返す。
  def self.Model(model_slug)
    model_dict[model_slug.to_sym]
  end

  # _uri_ を Diva::URI に変換する。
  # _uri_ が既に Diva::URI のインスタンスだった場合は _uri_ を返すので、Diva::URI
  # かもしれないオブジェクトを Diva::URI に変換するのに使う。
  # ==== Args
  # 以下のいずれかのクラスのインスタンス。
  # [Diva::URI] _uri_ をそのまま返す
  # [URI::Generic] Diva::URI.new(uri) の結果を返す
  # [Addressable::URI] Diva::URI.new(uri) の結果を返す
  # [String] _uri_ をURI文字列と見立てて、 URI::Generic または Addressable::URI に変換して、 Diva::URI のインスタンスを作る
  # [Hash] _uri_ を URI::Generic または Addressable::URI コンストラクタに渡して、URIを作り、 Diva::URI のインスタンスを作る
  # ==== Returns
  # [Diva::URI] 正しく変換できた
  # [nil] _uri_ が不正
  def self.URI(uri)
    case uri
    when Diva::URI
      uri
    when ::URI::Generic, Addressable::URI, String, Hash
      Diva::URI.new(uri)
    end
  end

  # ==== Raises
  # [Diva::InvalidURIError] _uri_ がURIではない場合
  def self.URI!(uri)
    self.URI(uri) or raise InvalidURIError, "`#{uri.class}' is not uri."
  end

  class << self
    private def model_dict
      @model ||= Hash.new do |h,k|
        ObjectSpace.each_object(Retriever::Model.singleton_class).find do |klass|
          if klass.slug
            h[klass.slug] = klass
          end
          klass.slug == k
        end
      end
    end
  end
end

module Mikutter
  module DivaHacks; end
end

require_relative 'diva_hacks/model'
require_relative 'diva_hacks/mixin'
require_relative 'diva_hacks/entity'
