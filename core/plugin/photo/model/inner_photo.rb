# -*- coding: utf-8 -*-

module Plugin::Photo
  class InnerPhoto < Diva::Model
    include Diva::Model::PhotoMixin

    field.uri :perma_link, required: true

  end
end
