# -*- coding: utf-8 -*-

module Plugin::Score
  class EmojiNote < Diva::Model
    register :score_emoji, name: "Emoji Note"

    field.string :description, required: true
    field.has :inline_photo, Diva::Model, required: true
    field.uri :uri, required: true

    # titleを1文字にしておかないとPangoで絵文字描画する時にsize倍の領域が取られてしまうので
    def title
      '.'
    end
  end
end
