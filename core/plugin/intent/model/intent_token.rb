# -*- coding: utf-8 -*-

module Plugin::Intent
  class IntentToken < Retriever::Model
    field.string :uri, required: true
    field.has    :model, Retriever::Model
    field.has    :intent, Plugin::Intent::Intent, required: true

    # 引数の情報からIntentTokenを作成し、それを開く
    def self.open(*args)
      self.new(*args).open
    end

    # 設定された情報を使ってURI又はModelを開く
    def open
      if model?
        Plugin.call(:open, self)
      else
        Deferred.new{
          Retriever.Model(intent.model_slug).find_by_uri(uri)
        }.next{|m|
          self.model = m
          Plugin.call(:open, self)
        }.terminate('なんか開けなかった')
      end
      self
    end
  end
end
