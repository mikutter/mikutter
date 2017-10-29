# -*- coding: utf-8 -*-
require_relative 'model/photo'
Plugin.create :photo do
  # 第一引数のpermalinkを指すModelを全て取得するフィルタ。
  # このフィルタでは、画像を指すModelしか返ってこない
  defevent :photo_filter,
           prototype: [Object, :<<]

  filter_photo_filter do |permalink, photos|
    photos << Plugin::Photo::Photo[permalink]
    [permalink, photos]
  end

  # Generic URI
  filter_uri_filter do |uri|
    if uri.is_a?(String) && uri.match(%r<\A\w+://>)
      [Addressable::URI.parse(uri)]
    else
      [uri]
    end
  end

  # Unix local file path
  filter_uri_filter do |uri|
    if uri.is_a?(String) && uri.start_with?('/')
      [Addressable::URI.new(scheme: 'file', path: uri)]
    else
      [uri]
    end
  end
end

