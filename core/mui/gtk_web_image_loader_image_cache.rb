# -*- coding: utf-8 -*-
# 画像のメモリキャッシュ・ディスクキャッシュ機能
# プラグインフィルタによるキャッシュ機能
# 画像のローカルパスの問い合わせ

miquire :mui, 'web_image_loader', 'web_image_loader_image_cache_raw', 'web_image_loader_image_cache_pixbuf'
miquire :lib, 'weakstorage'

module Gdk::WebImageLoader
  module ImageCache
    extend ImageCache

    def clear
      Raw.clear
      Pixbuf.clear
      @cache_mutex = nil
    end

    # 別々のスレッドで同じ _url_ に対して同時に処理を実行しない
    # ==== Args
    # [url] URL
    # ==== Return
    # ブロックの実行結果
    def synchronize(url)
      no_mainthread
      atomic { @cache_mutex ||= Hash.new{ |h, k| h[k] = Monitor.new } }
      cur = atomic { @cache_mutex[url] }.synchronize{
        yield } end

    # _url_ に対するMonitorがロックされているなら真を返す
    # ==== Args
    # [url] URL
    # ==== Return
    # 他のスレッドにロックされているなら真。
    # ロックされていても、自分がロックを持っている場合は偽。
    def locking?(url)
      atomic { @cache_mutex ||= Hash.new{ |h, k| h[k] = Monitor.new } }
      mon = atomic { @cache_mutex[url] }
      if mon.mon_try_enter
        mon.mon_exit
        false
      else
        true end end

  end
end
