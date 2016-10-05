# -*- coding: utf-8 -*-

module Retriever
  # _model_slug_ をslugとして持つModelクラスを返す。
  # 見つからない場合、nilを返す。
  def self.Model(model_slug)
    ObjectSpace.each_object(Retriever::Model.singleton_class) do |klass|
      return klass if klass.slug == model_slug
    end
    nil
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
require_relative 'retriever/entity/twitter_entity'
require_relative 'retriever/entity/url_entity'
