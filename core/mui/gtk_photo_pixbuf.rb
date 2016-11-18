# -*- coding: utf-8 -*-
miquire :lib, 'retriever/mixin/photo_mixin'

module Retriever::Model::PhotoMixin

  GdkPixbufCache = Struct.new(:pixbuf, :width, :height, :read_count, :reserver)

  # 特定のサイズのPixbufを作成するDeferredを返す
  def download_pixbuf(width:, height:)
    cache_get_defer(width: width, height: height).trap do |err|
      error err if err
      gen_pixbuf_from_raw_data(width: width, height: height)
    end
  end

  private

  def gen_pixbuf_from_raw_data(width:, height:)
    download.next{|photo|
      pb = pixbuf_cache_get(width: width, height: height)
      if pb
        pb
      else
        loader = Gdk::PixbufLoader.new
        loader.write photo.blob
        loader.close
        pb = loader.pixbuf
        pixbuf_cache_set(pb.scale(*calc_fitclop(pb, Gdk::Rectangle.new(0, 0, width, height))),
                  width: width,
                  height: height)
      end
    }
  end

  def cache_get_defer(width:, height:)
    Deferred.new.next do
      result = pixbuf_cache_get(width: width, height: height)
      if result
        result
      else
        Deferred.fail(result)
      end
    end
  end

  def pixbuf_cache_get(width:, height:)
    result = pixbuf_cache[[width, height].hash]
    if result
      result.read_count += 1
      result.reserver.cancel
      result.reserver = pixbuf_forget([width, height].hash, result.read_count)
      result.pixbuf
    end
  end

  def pixbuf_cache_set(pixbuf, width:, height:)
    if pixbuf_cache[[width, height].hash]
      error "cache already exists for #{uri} #{width}*#{height}"
      pixbuf_cache_get(width: width, height: height)
    else
      key = [width, height].hash
      pixbuf_cache[key] =
        GdkPixbufCache.new(pixbuf, width, height, 0, pixbuf_forget(key, 0))
      pixbuf
    end
  end

  def pixbuf_cache
    @pixbuf_cache ||= Hash.new
  end

  def pixbuf_forget(key, gen)
    Reserver.new([300, 60 * gen ** 2].max) do
      pixbuf_cache.delete(key)
    end
  end

  # _src_ が _rect_ にアスペクト比を維持した状態で内接するように縮小した場合のサイズを返す
  # ==== Args
  # [src] 元の寸法(Gtk::Rectangle)
  # [dst] 収めたい枠の寸法(Gtk::Rectangle)
  # ==== Return
  # 幅(px), 高さ(px)
  def calc_fitclop(src, dst)
    if (dst.width * src.height) > (dst.height * src.width)
      return src.width * dst.height / src.height, dst.height
    else
      return dst.width, src.height * dst.width / src.width
    end
  end
end
