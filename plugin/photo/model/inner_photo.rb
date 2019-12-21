# -*- coding: utf-8 -*-

module Plugin::Photo
  class InnerPhoto < Diva::Model
    include Diva::Model::PhotoMixin

    field.uri :perma_link, required: true

    def self.photos
      @photos ||= TimeLimitedStorage.new(Integer, self)
    end

    def self.[](uri)
      case uri
      when Photo
        uri.maximum_original
      when Diva::Model
        uri
      when URI, Addressable::URI, Diva::URI, String
        wrapped_uri = Diva::URI(uri)
        photos[wrapped_uri.to_s.hash] ||= new(perma_link: wrapped_uri)
      end
    end

    def initialize(*params)
      super
      self.class.photos[uri.to_s.hash] = self
    end
  end
end
