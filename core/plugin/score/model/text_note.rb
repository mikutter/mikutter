# -*- coding: utf-8 -*-

module Plugin::Score
  class TextNote < Diva::Model
    # register_model

    field.has :ancestor, Diva::Model, required: true
    field.string :description, required: true

    def inspect
      "text note(#{description})"
    end
  end
end
