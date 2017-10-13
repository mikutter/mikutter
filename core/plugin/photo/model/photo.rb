# -*- coding: utf-8 -*-
miquire :lib, 'retriever/mixin/photo_mixin'

module Plugin::Photo
  class Photo < Retriever::Model
    include Retriever::Model::PhotoMixin
    register :photo, name: Plugin[:photo]._('画像')

    field.uri :perma_link

    def self.photos
      @photos ||= TimeLimitedStorage.new(Integer, self)
    end

    def self.[](uri)
      case uri
      when self
        uri
      when URI, Addressable::URI, Retriever::URI, String
        photos[uri.to_s.hash] ||= new(perma_link: uri)
      end
    end

    def initialize(*params)
      super
      self.class.photos[uri.to_s.hash] = self
    end
  end
end
