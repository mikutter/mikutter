# -*- coding: utf-8 -*-
require 'skin'

module Plugin::Skin
  class Image < Diva::Model
    extend Memoist

    include Diva::Model::PhotoMixin

    register :skin_image, name: 'skin image'

    field.string :path, required: true

    def self.[](path)
      @store ||= Hash.new{|h,k| h[k] = new(path: k) } # path => Image
      @store[path]
    end

    memoize def uri
      Diva::URI.new(scheme: 'file'.freeze, path: path)
    end

    # 引数の寸法の GdkPixbuf::Pixbuf を返す。
    # ==== Args
    # [width:] Pixbufの幅(px)
    # [height:] Pixbufの高さ(px)
    # ==== Return
    # [GdkPixbuf::Pixbuf] メモリキャッシュやファイルシステムから画像が見つかった場合
    def pixbuf(width:, height:)
      result = pixbuf_cache[[width, height].hash]
      if result
        result.pixbuf
      else
        width, height = width.to_i, height.to_i
        pixbuf_cache_set(GdkPixbuf::Pixbuf.new(file: uri.path, width: width, height: height), width: width, height: height)
      end
    end

    private

    def pixbuf_forget(width, height, gen)
      unless width == height and [12, 16, 24, 32, 48, 64].include?(width)
        Reserver.new([300, 60 * gen ** 2].max, thread: SerialThread) do
          pixbuf_cache.delete([width, height].hash)
        end
      end
    end
  end
end
