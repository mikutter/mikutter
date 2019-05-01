module Plugin::Mastodon
  # https://github.com/tootsuite/documentation/blob/master/Using-the-API/API.md#mention
  class Mention < Diva::Model
    #register :mastodon_mention, name: "Mastodonメンション(Mastodon)"

    field.uri :url, required: true
    field.string :username, required: true
    field.string :acct, required: true
    field.string :id, required: true

    def inspect
      "mastodon-mention(#{acct})"
    end
  end
end
