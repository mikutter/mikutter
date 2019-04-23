module Plugin::Worldon
  # https://github.com/tootsuite/documentation/blob/master/Using-the-API/API.md#mention
  class Mention < Diva::Model
    #register :worldon_mention, name: "Mastodonメンション(Worldon)"

    field.uri :url, required: true
    field.string :username, required: true
    field.string :acct, required: true
    field.string :id, required: true

    def inspect
      "worldon-mention(#{acct})"
    end
  end
end
