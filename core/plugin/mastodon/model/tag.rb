module Plugin::Mastodon
  # https://github.com/tootsuite/documentation/blob/master/Using-the-API/API.md#tag
  class Tag < Diva::Model
    register :mastodon_tag, name: "Mastodonタグ"

    field.string :name, required: true
    field.uri :url, required: true

    def description
      "##{name}"
    end

    def path
      "/#{name}"
    end

    def inspect
      "mastodon-tag(#{name})"
    end
  end
end
