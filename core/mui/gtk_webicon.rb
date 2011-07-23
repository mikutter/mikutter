# -*- coding: utf-8 -*-
require File.expand_path('utils')
miquire :core, 'environment'
miquire :mui, 'skin'

require 'gtk2'
require 'net/http'
require 'uri'
require 'digest/md5'
require 'thread'
require 'observer'

# Web上の画像をレンダリングできる。
# レンダリング中は読み込み中の代替イメージが表示され、ロードが終了したら指定された画像が表示される。
# メモリキャッシュ、ストレージキャッシュがついてる。
module Gtk
  class WebIcon < Image

    include Observable

    attr_reader :loading_thread

    ICONDIR = "#{Environment::CONFROOT}icons#{File::SEPARATOR}"
    CACHE_EXPIRE = 2592000      # 一ヶ月

    @@image_download_lock = Mutex.new
    @@m_iconlock = Mutex.new
    @@l_iconring = Hash.new{ Mutex.new }
    @@pixbuf = @@oldpixbuf = Hash.new{ Hash.new{ Hash.new } }
    @@pixbufcache_lastcleartime = Time.now
    WebIconThread = SerialThreadGroup.new
    WebIconThread.max_threads = 16

    def initialize(img, width=48, height=48)
      @loading_thread = nil
      if(img.index('http://') == 0)
        filename = WebIcon.get_filename(img)
        if not(File.exist?(filename)) then
          @loading_thread = WebIcon.iconring(img, [width, height]){ |pic|
            if destroyed?
              notice "object destroyed"
            else
              self.pixbuf = pic
              self.changed
              self.notify_observers end }
          filename = File.expand_path(MUI::Skin.get("loading.png")) end
        img = filename end
      super(WebIcon.genpixbuf(img, width, height)) end

    # ファイル名に応じた Gdk::Pixbuf を返す。
    # ファイル名が外部URLだった場合、ロード中に表示するためのpixbufが返され、
    # ロードが終わったら _onload_ ブロックを、 Gdk::Pixbuf を引数にコールバックする。
    def self.get_icon_pixbuf(img, width=48, height=width, &onload)
      type_strict img => String
      if(img.index('http://') == 0)
        filename = WebIcon.get_filename(img)
        if not(File.exist?(filename)) then
          iconring(img, [width, height], &onload)
          filename = File.expand_path(MUI::Skin.get("loading.png")) end
        img = filename end
      WebIcon.genpixbuf(img, width, height) end

    # URL _img_ の画像を読み込む。読み込みが終わったら、ブロックにGdk::Pixbufを取って呼び出す
    # Gdk::Pixbufは _dim_ で指定された寸法(px)に収まるようにリサイズされて渡される
    # ロードをしているThreadを返す
    def self.iconring(img, dim=[48,48], &onload)
      WebIconThread.new{
        WebIcon.background_icon_loader(img, dim, &onload) } end

    # 外部URLからキャッシュファイル名を生成して返す
    def self.get_filename(url)
      ext = (File.extname(url).split("?", 2)[0] or File.extname(url))
      File.expand_path(self.icondir + Digest::MD5.hexdigest(url) + ext)
    end

    # ローカルファイル名 _filename_ の、pixbufキャッシュがあればそれを返す。
    def self.pixbuf_cache_get(filename, width, height)
      if @@pixbuf[filename][width][height]
        @@pixbuf[filename][width][height]
      elsif @@oldpixbuf[filename][width][height]
        @@pixbuf[filename][width][height] = @@oldpixbuf[filename][width][height] end end

    # ローカルファイル名 _filename_ の、pixbufキャッシュをセットする。
    def self.pixbuf_cache_set(filename, pixbuf)
      if @@pixbufcache_lastcleartime < Time.now
        notice 'pixbuf cache refreshed'
        @@pixbufcache_lastcleartime = Time.now + 60 * 30
        @@oldpixbuf = @@pixbuf
        @@pixbuf = Hash.new{ Hash.new{ Hash.new } } end
      @@pixbuf[filename][pixbuf.width][pixbuf.height] = pixbuf end

    # 外部URL _url_ に対するキャッシュファイルを削除する
    def self.remove_cache(url)
      filename = get_filename(url)
      if FileTest.exist?(File.expand_path(filename))
        File.delete(filename) rescue nil end end

    # 一ヶ月より古い画像を削除する。
    def self.garbage_collect
      File.delete(*Dir.glob("#{icon_dir}#{File::Separator}*").select(&method(:is_tooold))) rescue nil end

    # 画像が古すぎるならtrueを返す
    def self.is_tooold(file)
      Time.now - File.mtime(file) > CACHE_EXPIRE end

    # ローカルファイル名 _filename_ を読み込んで Gdk::Pixbuf オブジェクトを返す。
    # 既にメモリ内にロードされていれば、それを返す。
    def self.genpixbuf(filename, width=48, height=48)
      result = nil
      if FileTest.exist?(File.expand_path(filename))
        begin
          @@m_iconlock.synchronize{
            result = pixbuf_cache_get(filename, width, height)
            if not(result.is_a?(Gdk::Pixbuf))
              result = pixbuf_cache_set(filename,
                                        Gdk::Pixbuf.new(File.expand_path(filename), width, height)) end }
        rescue Gdk::PixbufError
          result = Gdk::Pixbuf.new(File.expand_path(MUI::Skin.get('notfound.png')), width, height) end end
      result end

    # アイコンをロードして、それが終わったらpixbufを作り、ブロックを呼び出す
    def self.background_icon_loader(img, dim=[48,48], &onload)
      no_mainthread
      filename = WebIcon.local_path(img)
      Delayer.new(Delayer::LATER){
        onload.call(self.genpixbuf(filename, *dim)) } end

    # 外部URL _url_ から画像をダウンロードして、ローカルファイル名を返す。
    # ロードに失敗した場合はロード失敗時の画像ファイル名を返す。
    def self.local_path(url)
      @@l_iconring[url].synchronize{
        filename = WebIcon.get_filename(url)
        if FileTest.exist?(filename)
          if is_tooold(filename)
            garbage_collect end
        else
          begin
            res = Net::HTTP.get_response(URI.parse(url))
            if(res.is_a?(Net::HTTPResponse)) and (res.code == '200')
              open(filename, 'wb'){ |f|
                f.write res.body }
            else
              filename = MUI::Skin.get("notfound.png") end
          rescue Timeout::Error, StandardError => e
            filename = MUI::Skin.get("notfound.png") end end
        filename } end

    # アイコンキャッシュ用ディレクトリを返す
    def self.icondir
      if not(FileTest.exist?(File.expand_path(ICONDIR)))
        FileUtils.mkdir_p File.expand_path(ICONDIR) end
      ICONDIR end
  end
end
