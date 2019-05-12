# coding: utf-8
module Plugin::Mastodon
  # https://github.com/tootsuite/documentation/blob/master/Using-the-API/API.md#emoji
  class Emoji < Diva::Model
    extend Memoist
    #register :mastodon_emoji, name: "Mastodon絵文字(Mastodon)"

    field.string :shortcode, required: true
    field.uri :static_url, required: true
    field.uri :url, required: true

    def description
      ":#{shortcode}:"
    end

    memoize def inline_photo
      Enumerator.new{|y| Plugin.filtering(:photo_filter, static_url, y) }.first
    end

    def path
      "/#{static_url.host}/#{shortcode}"
    end

    def inspect
      "mastodon-emoji(:#{shortcode}:)"
    end
  end
end
