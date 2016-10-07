# -*- coding: utf-8 -*-

module Plugin::Openimg
  class Album < Retriever::Model
    register :openimg_photo, name: Plugin[:openimg]._('画像ビューア')

    field.uri :perma_link

    handle ->uri{
      uri_str = uri.to_s
      openers = Plugin.filtering(:openimg_image_openers, Set.new).first
      openers.any?{ |opener| opener.condition === uri_str } if !openers.empty?
    } do |uri|
      new(perma_link: uri)
    end
  end
end
