# -*- coding: utf-8 -*-

module Plugin::Twitter
  class HashTag < Diva::Model
    register :twitter_hashtag, name: Plugin[:twitter]._("ハッシュタグ(Twitter)")

    field.string :name, required: true

    def title
      "##{name}"
    end

    def description
      "##{name}"
    end

    def perma_link
      Diva::URI.new("https://twitter.com/hashtag/#{CGI.escape(name)}")
    end
  end
end
