# -*- coding: utf-8 -*-
# 画像のメモリキャッシュ・ディスクキャッシュ機能
# プラグインフィルタによるキャッシュ機能
# 画像のローカルパスの問い合わせ

miquire :mui, 'web_image_loader', 'web_image_loader_image_cache_raw'
miquire :lib, 'weakstorage'

module Gdk::WebImageLoader
  module ImageCache
    extend ImageCache

    def clear
      Raw.clear
      @cache_mutex = nil
    end

    # 別々のスレッドで同じ _url_ に対して同時に処理を実行しない
    # ==== Args
    # [url] URL
    # ==== Return
    # ブロックの実行結果
    def synchronize(url)
      atomic { @cache_mutex ||= Hash.new{ |h, k| h[k] = Monitor.new } }
      cur = atomic { @cache_mutex[url] }.synchronize{
        yield } end
  end
end
