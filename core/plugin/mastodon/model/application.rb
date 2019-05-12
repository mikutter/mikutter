module Plugin::Mastodon
  # https://github.com/tootsuite/documentation/blob/master/Using-the-API/API.md#application
  class Application < Diva::Model
    register :mastodon_application, name: "Mastodonアプリケーション"

    field.string :name, required: true
    field.uri :website

    def inspect
      "mastodon-application(#{name})"
    end
  end
end
