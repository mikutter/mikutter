# -*- coding: utf-8 -*-
# 画像のURLを受け取って、Gtk::Pixbufを返す

miquire :mui, 'skin', 'web_image_loader_image_cache'
miquire :lib, 'memoize'
miquire :core, 'serialthread'
require 'net/http'
require 'uri'
require 'thread'

module Gdk::WebImageLoader
  extend Gdk::WebImageLoader

  WebIconThread = SerialThreadGroup.new # Gtk::WebIcon::WebIconThread
  WebIconThread.max_threads = 16

  # URLから画像をダウンロードして、その内容を持ったGdk::Pixbufのインスタンスを返す
  # ==== Args
  # [url] 画像のURL
  # [rect] 画像のサイズ(Gdk::Rectangle) または幅(px)
  # [height] 画像の高さ(px)
  # [&load_callback]
  #   画像のダウンロードで処理がブロッキングされるような場合、ブロックが指定されていれば
  #   このメソッドはとりあえずloading中の画像のPixbufを返し、ロードが完了したらブロックを呼び出す
  # ==== Return
  # Pixbuf
  def pixbuf(url, rect, height = nil, &load_callback)
    rect = Gdk::Rectangle.new(0, 0, rect, height) if height
    pixbuf = ImageCache::Pixbuf.load(url, rect)
    if(pixbuf)
      return pixbuf end
    if(is_local_path?(url))
      url = File.expand_path(url)
      if(FileTest.exist?(url))
        Gdk::Pixbuf.new(url, rect.width, rect.height)
      else
        notfound_pixbuf(rect.width, rect.height) end
    else
      via_internet(url, rect, &load_callback) end
  rescue Gdk::PixbufError
    notfound_pixbuf(rect) end

  # _url_ が指している画像を任意のサイズにリサイズして、その画像のパスを返す。
  # このメソッドは画像のダウンロードが発生すると処理をブロッキングする。
  # 取得に失敗した場合は nil を返す。
  # ==== Args
  # [url] 画像のURL
  # [width] 幅(px)
  # [height] 高さ(px)
  # ==== Return
  # 画像のパス
  def local_path(url, width = 48, height = width)
    ext = (File.extname(url).split("?", 2)[0] or File.extname(url))
    filename = File.expand_path(File.join(Environment::TMPDIR, Digest::MD5.hexdigest(url + "#{width}x#{height}") + ext + '.png'))
    pb = pixbuf(url, width, height)
    if(pb)
      pb.save(filename, 'png') if not FileTest.exist?(filename)
      local_path_files_add(filename)
      filename end end

  # _url_ が、インターネット上のリソースを指しているか、ローカルのファイルを指しているかを返す
  # ==== Args
  # [url] ファイルのパス又はURL
  # ==== Return
  # ローカルのファイルならtrue
  def is_local_path?(url)
    not url.start_with?('http') end

  # ロード中の画像のPixbufを返す
  # ==== Args
  # [rect] サイズ(Gtk::Rectangle) 又は幅(px)
  # [height] 高さ
  # ==== Return
  # Pixbuf
  def loading_pixbuf(rect, height = nil)
    rect = Gdk::Rectangle.new(0, 0, rect, height) if height
    Gdk::Pixbuf.new(File.expand_path(MUI::Skin.get("loading.png")), rect.width, rect.height).freeze
  end
  memoize :loading_pixbuf

  # 画像が見つからない場合のPixbufを返す
  # ==== Args
  # [rect] サイズ(Gtk::Rectangle) 又は幅(px)
  # [height] 高さ
  # ==== Return
  # Pixbuf
  def notfound_pixbuf(rect, height = nil)
    rect = Gdk::Rectangle.new(0, 0, rect, height) if height
    Gdk::Pixbuf.new(File.expand_path(MUI::Skin.get("notfound.png")), rect.width, rect.height).freeze
  end
  memoize :notfound_pixbuf

  private

  # urlが指している画像を引っ張ってきてPixbufを返す。
  # 画像をダウンロードする場合は、読み込み中の画像を返して、ロードが終わったらブロックを実行する
  # ==== Args
  # [url] 画像のURL
  # [rect] 画像のサイズ(Gdk::Rectangle)
  # [&load_callback] ロードが終わったら実行されるブロック
  # ==== Return
  # ロード中のPixbufか、キャッシュがあればロード後のPixbufを即座に返す
  # ブロックが指定されなければ、ロード完了まで待って、ロードが完了したらそのPixbufを返す
  def via_internet(url, rect, &load_callback) # :yield: pixbuf, exception, url
    raw = ImageCache::Raw.load(url)
    if raw
      ImageCache::Pixbuf.save(url, rect, inmemory2pixbuf(raw, rect))
    else
      pixbuf = nil
      exception = false
      load_proc = lambda {
        ImageCache.synchronize(url) {
          forerunner_result = ImageCache::Raw.load(url)
          if(forerunner_result)
            pixbuf = ImageCache::Pixbuf.save(url, rect, inmemory2pixbuf(forerunner_result, rect))
            if load_callback
              Delayer.new { load_callback.call(*[pixbuf, true, url][0..load_callback.arity]) }
              forerunner_result
            else
              pixbuf end
          else
            begin
              res = Net::HTTP.get_response(URI.parse(url))
              if(res.is_a?(Net::HTTPResponse)) and (res.code == '200')
                raw = res.body.to_s
                pixbuf = ImageCache::Pixbuf.save(url, rect, inmemory2pixbuf(raw, rect))
              else
                exception = true
                pixbuf = notfound_pixbuf(rect) end
            rescue Timeout::Error, StandardError => e
              exception = e
              pixbuf = notfound_pixbuf(rect) end
            ImageCache::Raw.save(url, raw)
            if load_callback
              Delayer.new { load_callback.call(*[pixbuf, exception, url][0..load_callback.arity]) }
              raw
            else
              pixbuf end end } }
      if load_callback
        WebIconThread.new(&load_proc)
        loading_pixbuf(rect)
      else
        load_proc.call end end
  rescue Gdk::PixbufError
    notfound_pixbuf(rect) end

  # メモリ上の画像データをPixbufにロードする
  # ==== Args
  # [image_data] メモリ上の画像データ
  # [rect] サイズ(Gdk::Rectangle)
  # ==== Return
  # Pixbuf
  def inmemory2pixbuf(image_data, rect)
    rect = rect.dup
    loader = Gdk::PixbufLoader.new
    # loader.set_size(rect.width, rect.height) if rect
    loader.write image_data
    loader.close
    pb = loader.pixbuf
    pb.scale(*calc_fitclop(pb, rect))
  rescue Gdk::PixbufError
    notfound_pixbuf(rect) end

  def local_path_files_add(path)
    atomic{
      if not defined?(@local_path_files)
        @local_path_files = Set.new
        at_exit{ FileUtils.rm(@local_path_files.to_a) } end }
    @local_path_files << path
  end

  def calc_fitclop(src, dst)
    if (dst.width * src.height) > (dst.height * src.width)
      return src.width * dst.height / src.height, dst.height
    else
      return dst.width, src.height * dst.width / src.width
    end
  end

end

