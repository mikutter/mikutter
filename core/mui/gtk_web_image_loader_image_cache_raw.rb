# -*- coding: utf-8 -*-

miquire :mui, 'web_image_loader_image_cache', 'web_image_loader'

module Gdk::WebImageLoader
  module ImageCache
    module Raw
      extend Raw

      # URLに対する画像の生データが残っている場合、それを返す
      # ==== Args
      # [url] 画像のURL
      # ==== Return
      # キャッシュがあれば、画像の生データ(String)、見つからなければnil
      def load(url)
        Gdk::WebImageLoader::ImageCache.synchronize(url) {
          raw = storage[url]
          if(raw)
            raw end } end

      # _url_ のリクエストの結果が _raw_ であるということを登録する
      # _raw_ が偽の場合は何もしない（キャッシュされない）
      # ==== Args
      # [url] 画像のurl
      # [raw] 画像の生データ
      # ==== Return
      # _raw_ の値
      def save(url, raw)
        Gdk::WebImageLoader::ImageCache.synchronize(url) {
          storage[url.freeze] = raw.freeze if raw } end

      def clear
        @storage = nil end

      private

      def storage
        @storage ||= TimeLimitedStorage.new(String, String) end

    end
  end
end
