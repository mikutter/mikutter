# -*- coding: utf-8 -*-
miquire :lib, 'retriever/mixin/photo_mixin'

module Retriever::PhotoMixin
  # 特定のサイズのPixbufを作成するDeferredを返す
  def download_pixbuf(width:, height:)
    download.next{|photo|
      loader = Gdk::PixbufLoader.new
      loader.write photo.blob
      loader.close
      pb = loader.pixbuf
      pb.scale(*calc_fitclop(pb, Gdk::Rectangle.new(0, 0, width, height)))
    }
  end

  private

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
