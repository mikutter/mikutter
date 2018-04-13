# -*- coding: utf-8 -*-

module Plugin::Score
  class HyperLinkNote < Diva::Model
    register :score_hyperlink, name: "Hyperlink Note"

    field.string :description, required: true
    field.uri :uri, required: true

    def inspect
      "hyperlink note(#{description}, #{uri})"
    end
  end
end
