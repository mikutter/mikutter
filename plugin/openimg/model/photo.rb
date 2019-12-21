# -*- coding: utf-8 -*-

module Plugin::Openimg
  class Photo < Diva::Model
    include Diva::Model::PhotoMixin
    register :openimg_photo, name: Plugin[:openimg]._('画像ビューア')

    field.uri    :perma_link

    handle ->uri{
      uri_str = uri.to_s
      openers = Plugin.filtering(:openimg_image_openers, Set.new).first
      openers.any?{ |opener| opener.condition === uri_str } if !openers.empty?
    } do |uri|
      new(perma_link: uri)
    end

    private

    def download_routine
      _, raw = Plugin.filtering(:openimg_raw_image_from_display_url, perma_link.to_s, nil)
      if raw
        download_mainloop(raw)
      else
        raise "couldn't resolve actual image url of #{perma_link}."
      end
    rescue EOFError
      true
    ensure
      raw.close rescue nil
    end
  end
end
