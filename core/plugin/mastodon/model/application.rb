module Plugin::Worldon
  # https://github.com/tootsuite/documentation/blob/master/Using-the-API/API.md#application
  class Application < Diva::Model
    register :worldon_application, name: "Mastodonアプリケーション(Worldon)"

    field.string :name, required: true
    field.uri :website

    def inspect
      "worldon-application(#{name})"
    end
  end
end
