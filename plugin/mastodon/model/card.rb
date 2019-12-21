module Plugin::Mastodon
  # https://docs.joinmastodon.org/api/entities/#card
  class Card < Diva::Model
    register :mastodon_card, name: Plugin[:mastodon]._('Mastodonカード')

    field.uri :url, required: true
    field.string :title, required: true
    field.string :description, required: true
    field.uri :image
    field.string :type, required: true # one of "link", "photo", "video", "rich"
    field.string :author_name
    field.uri :author_url
    field.string :provider_name
    field.uri :provider_url
    field.string :html
    field.int :width
    field.int :height

    def path
      "/#{CGI.escape(url)}"
    end

    def inspect
      "mastodon-card(#{name})"
    end
  end
end
