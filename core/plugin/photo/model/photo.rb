# -*- coding: utf-8 -*-
require_relative 'photo_variant'

module Plugin::Photo
  # 同じ画像の別々のvariantをまとめて管理するModel。
  # これ自体をPhoto Modelのように扱うことができ、要求に応じて適切なvariantを使い分ける。
  class Photo < Diva::Model
    include Diva::Model::PhotoInterface
    register :photo, name: Plugin[:photo]._('画像')

    field.has :variants, [Diva::Model], required: true
    field.has :original, InnerPhoto
    field.uri :perma_link, required: true

    def self.photos
      @photos ||= TimeLimitedStorage.new(Integer, self)
    end

    def self.[](uri)
      case uri
      when self
        uri
      when URI, Addressable::URI, Diva::URI
        photos[uri.to_s.hash] ||= wrap(inner_photo(uri))
      when String
        if uri.start_with?('http')
          photos[uri.hash] ||= wrap(inner_photo(uri))
        elsif uri.start_with?('/')
          uri = Diva::URI.new(scheme: 'file', path: uri)
          photos[uri.hash] ||= wrap(inner_photo(uri))
        end
      end
    end

    # ==== seedsのpolicyキーについて
    # policyは以下のいずれかの値。
    # [:original] オリジナル画像。一つだけ含まれていること。
    # [その他] Plugin::Photo::PhotoVariantを参照
    def self.generate(seeds, perma_link:)
      orig, other = seeds.partition{|s| s[:policy] == :original }
      new(variants: other.map{|s|
            PhotoVariant.new(s.merge(photo: inner_photo(s[:photo])))
          },
          perma_link: perma_link,
          original: inner_photo(orig.first[:photo]))
    end

    def self.wrap(inner_photo)
      new(variants: [],
          perma_link: inner_photo.perma_link,
          original: inner_photo)
    end

    def self.inner_photo(model_or_uri)
      case model_or_uri
      when String, URI, Addressable::URI, Diva::URI
        InnerPhoto.new(perma_link: model_or_uri)
      else
        model_or_uri
      end
    end

    # TODO: 各variantのURLにselfをキャッシュされてるかテストする
    def initialize(*params)
      super
      each_photos do |photo|
        self.class.photos[photo.uri.to_s.hash] = self
      end
      self.class.photos[uri.to_s.hash] = self
    end

    # variantが保持している各Photo Modelを引数にしてblockを呼び出す。
    # blockを指定しなかった場合は、Enumeratorを返す
    # ==== Return
    # [self] ブロックを渡した場合
    # [Enumerator] Photo Modelを列挙するEnumerator
    def each_photos(&block)
      if block_given?
        variants.each{|pv| block.(pv.photo) }
        self
      else
        variants.lazy.map(&:photo)
      end
    end

    def download(width: nil, height: nil, &partial_callback)
      maximum_original.download(width: width, height: height, &partial_callback)
    end

    # PhotoInterfaceをgtkプラグインが拡張し、内部でこのメソッドを呼ぶ。
    # このModelでは必要ないため空のメソッドを定義しておく。
    def increase_read_count
    end

    def blob
      maximum_original.blob
    end

    # 最大サイズのPhotoを返す。
    # originalがあればそれを返すが、なければfit policyのvariantのうち最大のものを返す。
    # ==== Return
    # [Photo Model] 最大のPhoto
    def maximum
      self.class.wrap(maximum_original)
    end

    private

    def maximum_original
      if original
        original
      else
        variant = variants.find{|v| v.policy.to_sym == :fit }
        if variant
          variant.photo
        else
          variants.sample.photo
        end
      end
    end
  end
end

