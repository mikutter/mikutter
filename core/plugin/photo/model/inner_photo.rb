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
      when URI, Addressable::URI, Diva::URI
        photos[uri.to_s.hash] ||= new(perma_link: uri)
      when String
        if uri.start_with?('http')
          photos[uri.hash] ||= new(perma_link: uri)
        elsif uri.start_with?('/')
          uri = Diva::URI.new(scheme: 'file', path: uri)
          photos[uri.hash] ||= new(perma_link: uri)
        end
      end
    end

    def initialize(*params)
      super
      self.class.photos[uri.to_s.hash] = self
    end
  end
end
