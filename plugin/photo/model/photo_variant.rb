# -*- coding: utf-8 -*-
require_relative 'inner_photo'

module Plugin::Photo
  # ==== policyについて
  # policyは以下のいずれかの値。
  # [:fit] オリジナルからアスペクト比を保って縮小したもの
  # [その他] 何からの加工が施されたもの。自動では選択されない
  class PhotoVariant < Diva::Model
    field.string :name, required: true
    field.string :policy, required: true
    field.int :width, required: true
    field.int :height, required: true
    field.has :photo, Diva::Model, required: true

    def inspect
      "#<PhotoVariant: #{name}(#{policy}, #{width}*#{height}) #{photo.inspect}>"
    end
  end
end

