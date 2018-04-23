# coding: utf-8
module Plugin::Worldon
  # https://github.com/tootsuite/documentation/blob/master/Using-the-API/API.md#emoji
  class Emoji < Diva::Model
    #register :worldon_emoji, name: "Mastodon絵文字(Worldon)"

    field.string :shortcode, required: true
    field.uri :static_url, required: true
    field.uri :url, required: true

    def description
      ":#{shortcode}:"
    end

    memoize def inline_photo
      Enumerator.new{|y| Plugin.filtering(:photo_filter, perma_link, y) }.first
    end

    def perma_link
      static_url
    end
  end
end
