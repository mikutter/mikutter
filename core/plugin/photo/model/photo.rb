# -*- coding: utf-8 -*-

module Plugin::Photo
  class Photo < Diva::Model
    include Diva::Model::PhotoMixin
    register :photo, name: Plugin[:photo]._('画像')

    field.uri :perma_link

    def self.photos
      @photos ||= TimeLimitedStorage.new(Integer, self)
    end

    def self.[](uri)
      case uri
      when self
        uri
      when URI, Addressable::URI, Diva::URI, String
        photos[uri.to_s.hash] ||= new(perma_link: uri)
      end
    end

    def initialize(*params)
      super
      self.class.photos[uri.to_s.hash] = self
    end
  end
end
