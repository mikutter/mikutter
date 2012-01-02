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
        storage[url] || load_by_filter(url) end

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

      def load_by_filter(url)
        raw = Plugin.filtering(:image_cache, url, nil)[1]
        raw.is_a?(String) and raw end

      def storage
        @storage ||= TimeLimitedStorage.new(String, String) end

    end
  end
end
