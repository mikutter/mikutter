# -*- coding: utf-8 -*-

module Plugin::Score
  class EmojiNote < Diva::Model
    register :score_emoji, name: "Emoji Note"

    field.string :description, required: true
    field.has :inline_photo, Diva::Model, required: true
  end
end
