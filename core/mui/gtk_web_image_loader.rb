# -*- coding: utf-8 -*-
# 画像のURLを受け取って、Gtk::Pixbufを返す

miquire :core, 'serialthread', 'skin'
miquire :mui, 'web_image_loader_image_cache'
miquire :lib, 'memoize', 'addressable/uri'
require 'net/http'
require 'uri'
require 'thread'

module Gdk::WebImageLoader
  extend Gdk::WebImageLoader

  WebImageThread = SerialThreadGroup.new
  WebImageThread.max_threads = 16

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
    url = Plugin.filtering(:web_image_loader_url_filter, url.freeze)[0].freeze
    rect = Gdk::Rectangle.new(0, 0, rect, height) if height
    pixbuf = ImageCache::Pixbuf.load(url, rect)
    return pixbuf if pixbuf
    if(is_local_path?(url))
      url = File.expand_path(url)
      if(FileTest.exist?(url))
        Gdk::Pixbuf.new(url, rect.width, rect.height)
      else
        notfound_pixbuf(rect) end
    else
      via_internet(url, rect, &load_callback) end
  rescue Gdk::PixbufError
    notfound_pixbuf(rect)
  rescue => e
    if into_debug_mode(e)
      raise e
    else
      notfound_pixbuf(rect) end end

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
    url.freeze
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
  def get_raw_data(url, &load_callback) # :yield: raw, exception, url
    url.freeze
    raw = ImageCache::Raw.load(url)
    if raw and not raw.empty?
      raw
    else
      exception = nil
      if load_callback
        WebImageThread.new{
          get_raw_data_load_proc(url, &load_callback) }
        :wait
      else
        get_raw_data_load_proc(url, &load_callback) end end
  rescue Gdk::PixbufError
    nil end

  # get_raw_dataの内部関数。
  # HTTPコネクションを張り、 _url_ をダウンロードしてjpegとかpngとかの情報をそのまま返す。
  def get_raw_data_load_proc(url, &load_callback)
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
          raw end end } end

  # get_raw_dataのdeferred版
  def get_raw_data_d(url)
    url.freeze
    promise = Deferred.new
    Thread.new {
      result = get_raw_data(url){ |raw, e, url|
        begin
          if e
            promise.fail(e)
          elsif raw and not raw.empty?
            promise.call(raw)
          else
            promise.fail(raw) end
        rescue Exception => e
          promise.fail(e) end }
      if result
        if :wait != result
          promise.call(result) end
      else
        promise.fail(result) end }
    promise end

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
    Gdk::Pixbuf.new(File.expand_path(Skin.get("loading.png")), width, height).freeze end
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
    Gdk::Pixbuf.new(File.expand_path(Skin.get("notfound.png")), width, height).freeze
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
    url.freeze
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

  def http(host, port)
    result = nil
    atomic{
      @http_pool = Hash.new{|h, k|h[k] = {} } if not defined? @http_pool
      if not @http_pool[host][port]
        pool = []
        @http_pool[host][port] = Queue.new
        4.times { |index|
          http = Net::HTTP.new(host, port)
          http.open_timeout=5
          http.read_timeout=30
          pool << http
          @http_pool[host][port].push(pool) } end }
    pool = @http_pool[host][port].pop
    http = pool.pop
    result = yield(http)
  ensure
    pool.push(http) if defined? http
    @http_pool[host][port].push(pool) if defined? pool
    result
  end

  def get_icon_via_http(url)
    uri = Addressable::URI.parse(url)
    request = Net::HTTP::Get.new(uri.request_uri)
    request['Connection'] = 'Keep-Alive'
    http(uri.host, uri.port) do |http|
      begin
        http.request(request)
      rescue EOFError => e
        http.finish
        http.start
        notice "open connection for #{uri.host}"
        http.request(request) end end end

  def local_path_files_add(path)
    atomic{
      if not defined?(@local_path_files)
        @local_path_files = Set.new
        at_exit{ FileUtils.rm(@local_path_files.to_a) } end }
    @local_path_files << path
  end
end

