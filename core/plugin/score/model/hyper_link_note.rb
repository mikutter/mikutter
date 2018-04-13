# -*- coding: utf-8 -*-

module Plugin::Score
  class HyperLinkNote < Diva::Model
    register :score_hyperlink, name: "Hyperlink Note"

    field.string :description, required: true
    field.uri :uri, required: true
    field.has :reference, Diva::Model, required: false

    def inspect
      "hyperlink note(#{description}, #{uri})"
    end
  end
end
