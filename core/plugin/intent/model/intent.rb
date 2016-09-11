# -*- coding: utf-8 -*-

module Plugin::Intent
  class Intent < Retriever::Model
    field.string :slug, required: true
    field.string :label, required: true
  end
end
