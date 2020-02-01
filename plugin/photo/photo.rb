# -*- coding: utf-8 -*-
require_relative 'model/photo'
Plugin.create :photo do
  # 第一引数のpermalinkを指すModelを全て取得するフィルタ。
  # このフィルタでは、画像を指すModelしか返ってこない
  defevent :photo_filter,
           prototype: [Object, Pluggaloid::COLLECT]

  filter_photo_filter do |permalink, photos|
    photos << Plugin::Photo::Photo[permalink]
    [permalink, photos]
  end
end

