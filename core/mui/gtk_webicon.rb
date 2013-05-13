# -*- coding: utf-8 -*-
# ／(^o^)＼
require File.expand_path(File.dirname(__FILE__+'/utils'))
miquire :core, 'environment', 'serialthread', 'skin'
miquire :mui, 'web_image_loader'

require 'gtk2'
require 'observer'

# Web上の画像をレンダリングできる。
# レンダリング中は読み込み中の代替イメージが表示され、ロードが終了したら指定された画像が表示される。
# メモリキャッシュ、ストレージキャッシュがついてる。
module Gtk
  class WebIcon < Image

    DEFAULT_RECTANGLE = Gdk::Rectangle.new(0, 0, 48, 48)

    include Observable

    # ==== Args
    # [url] 画像のURLもしくはパス(String)
    # [rect] 画像のサイズ(Gdk::Rectangle) または幅(px)
    # [height] 画像の高さ(px)
    def initialize(url, rect = DEFAULT_RECTANGLE, height = nil)
      rect = Gdk::Rectangle.new(0, 0, rect, height) if height
      if(Gdk::WebImageLoader.is_local_path?(url))
        url = File.expand_path(url)
        if(FileTest.exist?(url))
          super(Gdk::Pixbuf.new(url, rect.width, rect.height))
        else
          super(Gdk::WebImageLoader.notfound_pixbuf(rect.width, rect.height)) end
      else
        super(Gdk::WebImageLoader.pixbuf(url, rect.width, rect.height) { |pixbuf, success|
                unless destroyed?
                  self.pixbuf = pixbuf
                  self.changed
                  self.notify_observers end }) end end

  end
end
