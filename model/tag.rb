module Plugin::Worldon
  # https://github.com/tootsuite/documentation/blob/master/Using-the-API/API.md#tag
  class Tag < Diva::Model
    #register :worldon_tag, name: "Mastodonタグ(Worldon)"

    field.string :name, required: true
    field.uri :url, required: true

    def inspect
      "worldon-tag(#{name})"
    end
  end
end
