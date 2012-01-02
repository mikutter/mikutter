# -*- coding: utf-8 -*-

miquire :mui, 'web_image_loader_image_cache', 'web_image_loader'

module Gdk::WebImageLoader
  module ImageCache
    module Pixbuf
      extend Pixbuf
      extend MonitorMixin

      # URLに対する画像のPixbufが残っている場合、それを返す
      # ==== Args
      # [url] 画像のURL
      # [rect] 画像の寸法(Gdk::Rectangle)
      # ==== Return
      # キャッシュがあれば、画像の生データ(String)、見つからなければnil
      def load(url, rect)
        if(defined?(storage[url][rect.width][rect.height]))
          storage[url][rect.width][rect.height] end end

      # _url_ のリクエストの結果が _raw_ であるということを登録する
      # _raw_ が偽の場合は何もしない（キャッシュされない）
      # ==== Args
      # [url] 画像のurl
      # [rect] 画像の寸法(Gdk::Rectangle)
      # [pixbuf] Pixbufのデータ
      # ==== Return
      # _raw_ の値
      def save(url, rect, pixbuf)
        return pixbuf if not pixbuf
        synchronize {
          storage[url] ||= {}
          storage[url][rect.width] ||= {}
          storage[url][rect.width][rect.height] = pixbuf.freeze }
        pixbuf end

      def clear
        @storage = nil end

      private

      def storage
        @storage ||= TimeLimitedStorage.new(String, Hash)
      end

    end
  end
end
