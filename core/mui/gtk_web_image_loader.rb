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

  WebImageThread = Hash.new { |h, k|
    stg = SerialThreadGroup.new
    stg.max_threads = 1
    h[k] = stg }

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
    if Gdk::WebImageLoader::ImageCache.locking?(url)
      downloading_anotherthread_case(url, rect, &load_callback)
    else
      pixbuf = ImageCache::Pixbuf.load(url, rect)
      return pixbuf if pixbuf
      if(is_local_path?(url))
        url = File.expand_path(url)
        if(FileTest.exist?(url))
          Gdk::Pixbuf.new(url, rect.width, rect.height)
        else
          notfound_pixbuf(rect) end
      else
        via_internet(url, rect, &load_callback) end end
  rescue Gdk::PixbufError
    notfound_pixbuf(rect)
  rescue => e
    into_debug_mode(e)
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

  # urlが指している画像のデータを返す。
  # ==== Args
  # [url] 画像のURL
  # ==== Return
  # キャッシュがあればロード後のデータを即座に返す。
  # ブロックが指定されれば、キャッシュがない時は :wait を返して、ロードが完了したらブロックを呼び出す。
  # ブロックが指定されなければ、ロード完了まで待って、ロードが完了したらそのデータを返す。
  def get_raw_data(url, &load_callback) # :yield: pixbuf, exception, url
    raw = ImageCache::Raw.load(url)
    if raw
      raw
    else
      exception = nil
      load_proc = lambda {
        ImageCache.synchronize(url) {
          forerunner_result = ImageCache::Raw.load(url)
          if(forerunner_result)
            raw = forerunner_result
            if load_callback
              load_callback.call(*[forerunner_result, nil, url][0..load_callback.arity])
              forerunner_result
            else
              forerunner_result end
          else
            no_mainthread
            begin
              res = get_icon_via_http(url)
              if(res.is_a?(Net::HTTPResponse)) and (res.code == '200')
                raw = res.body.to_s
              else
                exception = true end
            rescue Timeout::Error, StandardError => e
              exception = e end
            ImageCache::Raw.save(url, raw)
            if load_callback
              load_callback.call(*[raw, exception, url][0..load_callback.arity])
              raw
            else
              raw end end } }
      if load_callback
        web_image_thread(url, &load_proc)
        :wait
      else
        load_proc.call end end
  rescue Gdk::PixbufError
    nil end

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
    if height
      _loading_pixbuf(rect, height)
    else
      _loading_pixbuf(rect.width, rect.height) end end
  def _loading_pixbuf(width, height)
    Gdk::Pixbuf.new(File.expand_path(MUI::Skin.get("loading.png")), width, height).freeze end
  memoize :_loading_pixbuf

  # 画像が見つからない場合のPixbufを返す
  # ==== Args
  # [rect] サイズ(Gtk::Rectangle) 又は幅(px)
  # [height] 高さ
  # ==== Return
  # Pixbuf
  def notfound_pixbuf(rect, height = nil)
    if height
      _notfound_pixbuf(rect, height)
    else
      _notfound_pixbuf(rect.width, rect.height) end end
  def _notfound_pixbuf(width, height)
    Gdk::Pixbuf.new(File.expand_path(MUI::Skin.get("notfound.png")), width, height).freeze
  end
  memoize :_notfound_pixbuf

  # _src_ が _rect_ にアスペクト比を維持した状態で内接するように縮小した場合のサイズを返す
  # ==== Args
  # [src] 元の寸法(Gtk::Rectangle)
  # [dst] 収めたい枠の寸法(Gtk::Rectangle)
  # ==== Return
  # Pixbuf
  def calc_fitclop(src, dst)
    if (dst.width * src.height) > (dst.height * src.width)
      return src.width * dst.height / src.height, dst.height
    else
      return dst.width, src.height * dst.width / src.width end end

  private

  # _url_ のホスト名１つにつき同時に指定された数だけブロックを実行する
  # ==== Args
  # [url] URL
  # [&proc] 実行するブロック
  def web_image_thread(url, &proc)
    uri = URI.parse(url)
    if uri.host
      WebImageThread[uri.host].new(&proc)
    else
      raise 'ホスト名が設定されていません' end end

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
    if block_given?
      raw = get_raw_data(url){ |raw, exception|
        pixbuf = notfound_pixbuf(rect)
        begin
          pixbuf = ImageCache::Pixbuf.save(url, rect, inmemory2pixbuf(raw, rect, true)) if raw
        rescue Gdk::PixbufError => e
          exception = e
        end
        Delayer.new{ load_callback.call(pixbuf, exception, url) } }
      if raw.is_a?(String)
        ImageCache::Pixbuf.save(url, rect, inmemory2pixbuf(raw, rect))
      else
        loading_pixbuf(rect) end
    else
      raw = get_raw_data(url)
      if raw
        ImageCache::Pixbuf.save(url, rect, inmemory2pixbuf(raw, rect))
      else
        notfound_pixbuf(rect) end end
  rescue Gdk::PixbufError
    notfound_pixbuf(rect) end

  # メモリ上の画像データをPixbufにロードする
  # ==== Args
  # [image_data] メモリ上の画像データ
  # [rect] サイズ(Gdk::Rectangle)
  # [raise_exception] 真PixbufError例外を投げる(default: false)
  # ==== Exceptions
  # Gdk::PixbufError例外が発生したら、notfound_pixbufを返します。
  # ただし、 _raise_exception_ が真なら例外を投げます。
  # ==== Return
  # Pixbuf
  def inmemory2pixbuf(image_data, rect, raise_exception = false)
    rect = rect.dup
    loader = Gdk::PixbufLoader.new
    # loader.set_size(rect.width, rect.height) if rect
    loader.write image_data
    loader.close
    pb = loader.pixbuf
    pb.scale(*calc_fitclop(pb, rect))
  rescue Gdk::PixbufError => e
    if raise_exception
      raise e
    else
      notfound_pixbuf(rect) end end

  # Gdk::WebImageLoader.pixbuf が呼ばれた時に、他のスレッドでそのURLの画像を
  # ダウンロード中だった場合の処理
  # ==== Args
  # Gdk::WebImageLoader.pixbuf を参照
  # ==== Return
  # Pixbuf
  def downloading_anotherthread_case(url, rect, &load_callback)
    if(load_callback)
      web_image_thread(url) {
        pixbuf = ImageCache::Pixbuf.load(url, rect)
        Delayer.new{ load_callback.call(pixbuf) } }
      loading_pixbuf(rect)
    else
      ImageCache::Pixbuf.load(url, rect) end
  rescue Gdk::PixbufError
    notfound_pixbuf(rect) end

  def gen_http_obj(host, port)
    http = Net::HTTP.new(host, port)
    http.open_timeout=5
    http.read_timeout=30
    notice "open connection for #{host}"
    http.start end
  memoize :gen_http_obj

  def get_icon_via_http(url)
    uri = URI.parse(url)
    request = Net::HTTP::Get.new(uri.request_uri)
    request['Connection'] = 'Keep-Alive'
    http = gen_http_obj(uri.host, uri.port)
    http.request(request)
  rescue EOFError => e
    http.finish
    http.start
    notice "reopen connection for #{uri.host}"
    http.request(request)
  end

  def local_path_files_add(path)
    atomic{
      if not defined?(@local_path_files)
        @local_path_files = Set.new
        at_exit{ FileUtils.rm(@local_path_files.to_a) } end }
    @local_path_files << path
  end
end

