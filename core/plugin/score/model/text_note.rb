# -*- coding: utf-8 -*-

module Plugin::Score
  class TextNote < Diva::Model
    register :score_text, name: "Text Note"

    field.string :description, required: true

    def inspect
      "text note(#{description})"
    end
  end
end
