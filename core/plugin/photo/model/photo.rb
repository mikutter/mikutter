# -*- coding: utf-8 -*-
require_relative 'photo_variant'

module Plugin::Photo
  # 1種類の画像を扱うModel。
  # 同じ画像の複数のサイズ、別形式（Photo Variant）を含むことができ、それらを自動的に使い分ける。
  class Photo < Diva::Model
    include Diva::Model::PhotoInterface
    register :photo, name: Plugin[:photo]._('画像')

    field.has :variants, [Diva::Model], required: true
    field.has :original, InnerPhoto
    field.uri :perma_link, required: true

    def self.photos
      @photos ||= TimeLimitedStorage.new(Integer, self)
    end

    # URIからPhoto Modelを得る。
    # _uri_ がDiva::Modelだった場合はそれを返すので、PhotoかURIかわからないものをPhotoに変換するのに使える。
    # サードパーティプラグインはこれを呼ばず、以下のページを参考にすること。
    def self.[](uri)
      case uri
      when Diva::Model
        uri
      when URI, Addressable::URI, Diva::URI
        photos[uri.to_s.hash] ||= wrap(uri)
      when String
        if uri.start_with?('http')
          photos[uri.hash] ||= wrap(uri)
        elsif uri.start_with?('/')
          uri = Diva::URI.new(scheme: 'file', path: uri)
          photos[uri.hash] ||= wrap(uri)
        end
      end
    end

    # _perma_link_ のURIをもつPhotoが既にある場合、それを返す。
    # ない場合は、 _seeds_ の内容を元に作る。
    # ==== Args
    # [seeds] variant情報のEnumerator(後述)
    # [perma_link:] variantの代表となるパーマリンク
    # ===== seedsについて
    # 有限個のHashについて繰り返すEnumeratorで、 _perma_link_ に対応するPhotoがまだ作られていない場合にだけ利用される。
    # 各Hashは以下のキーを持つ。
    # :name :: そのvariantの名前。Photoの管理上特に利用されないので、重複していても良い(Symbol)
    # :width :: そのvariantの画像の幅(px)
    # :height :: そのvariantの画像の高さ(px)
    # :policy :: オリジナルからどのようにリサイズされたかを示す値(Symbol)
    # :photo :: そのvariantの画像を示すPhoto Model又は画像のURL
    # ===== seedsのpolicyキーについて
    # policyは以下のいずれかの値。
    # [:original] オリジナル画像。一つだけ含まれていること。
    # [その他] Plugin::Photo::PhotoVariantを参照
    def self.generate(seeds, perma_link:)
      cached = photos[perma_link.to_s.hash]
      return cached if cached
      orig, other = seeds.partition{|s| s[:policy] == :original }
      new(variants: other.map{|s|
            PhotoVariant.new(s.merge(photo: InnerPhoto[s[:photo]]))
          },
          perma_link: perma_link,
          original: InnerPhoto[orig.first[:photo]])
    end

    def self.wrap(model_or_uri)
      inner_photo = InnerPhoto[model_or_uri]
      new(variants: [],
          perma_link: inner_photo.perma_link,
          original: inner_photo)
    end

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
      if width && height
        larger_than(width: width, height: height)
          .download(width: width, height: height, &partial_callback)
      else
        maximum_original.download(width: width, height: height, &partial_callback)
      end
    end

    # PhotoInterfaceをgtkプラグインが拡張し、内部でこのメソッドを呼ぶ。
    # このModelでは必要ないため空のメソッドを定義しておく。
    def increase_read_count
    end

    def blob
      maximum_original.blob
    end

    # 指定された幅と高さを上回るvariantのなかで最小のものを返す
    # ==== Args
    # [width:] (Integer)
    # [height:] (Integer)
    # ==== Return
    # [Photo Model] 最適なPhoto Model
    def larger_than(width:, height:)
      largers = variants.select{|pv| pv.policy.to_sym == :fit && pv.width >= width && pv.height >= height }
      if largers.empty?
        maximum_original
      else
        largers.min_by{|pv| pv.width }.photo
      end
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

