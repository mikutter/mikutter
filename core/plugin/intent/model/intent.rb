# -*- coding: utf-8 -*-

module Plugin::Intent
  class Intent < Retriever::Model
    field.string :slug, required: true # Intentのslug
    field.string :label, required: true
    field.string :model_slug, required: true
  end
end
