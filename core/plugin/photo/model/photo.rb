# -*- coding: utf-8 -*-
miquire :lib, 'retriever/mixin/photo_mixin'

module Plugin::Photo
  class Photo < Retriever::Model
    include Retriever::PhotoMixin
    register :photo, name: Plugin[:photo]._('画像')

    field.uri :perma_link
  end
end
