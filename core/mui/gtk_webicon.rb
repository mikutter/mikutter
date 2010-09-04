miquire :core, 'utils'
miquire :core, 'environment'
miquire :mui, 'skin'

require 'gtk2'
require 'net/http'
require 'uri'
require 'digest/md5'
require 'thread'
require 'observer'

module Gtk
  class WebIcon < Image

    include Observable

    ICONDIR = "#{Environment::CONFROOT}icons#{File::SEPARATOR}"

    @@image_download_lock = Mutex.new
    @@m_iconlock = Mutex.new
    @@l_iconring = Hash.new{ Mutex.new }
    @@pixbuf = @@oldpixbuf = Hash.new{ Hash.new{ Hash.new } }
    @@pixbufcache_lastcleartime = Time.now

    def initialize(img, width=48, height=48)
      if(img.index('http://') == 0) then
        filename = WebIcon.get_filename(img)
        if not(File.exist?(filename)) then
          WebIcon.iconring(self, img, [width, height])
          filename = File.expand_path(MUI::Skin.get("loading.png"))
        end
        img = filename
      end
      super(WebIcon.genpixbuf(img, width, height))
    end

    def self.get_filename(url)
      File.expand_path(self.icondir + Digest::MD5.hexdigest(url) + File.extname(url))
    end

    def self.iconring(this, img, dim=[48,48])
      Thread.new{
        WebIcon.background_icon_loader(this, img, dim)
      }
    end

    def self.pixbuf_cache_get(filename, width, height)
      if @@pixbuf[filename][width][height]
        @@pixbuf[filename][width][height]
      elsif @@oldpixbuf[filename][width][height]
        @@pixbuf[filename][width][height] = @@oldpixbuf[filename][width][height] end end

    def self.pixbuf_cache_set(filename, pixbuf)
      if @@pixbufcache_lastcleartime < Time.now
        notice 'pixbuf cache refreshed'
        @@pixbufcache_lastcleartime = Time.now + 60 * 30
        @@oldpixbuf = @@pixbuf
        @@pixbuf = Hash.new{ Hash.new{ Hash.new } } end
      @@pixbuf[filename][pixbuf.width][pixbuf.height] = pixbuf end

    def self.genpixbuf(filename, width=48, height=48)
      result = nil
      begin
        @@m_iconlock.synchronize{
          result = pixbuf_cache_get(filename, width, height)
          if not(result.is_a?(Gdk::Pixbuf))
            result = pixbuf_cache_set(filename,
                                      Gdk::Pixbuf.new(File.expand_path(filename), width, height)) end }
      rescue Gdk::PixbufError
        result = Gdk::Pixbuf.new(File.expand_path(MUI::Skin.get('notfound.png')), width, height) end
      result end

    def self.background_icon_loader(this, img, dim=[48,48])
      filename = WebIcon.local_path(img)
      Delayer.new(Delayer::LATER){
        Lock.synchronize{
          this.pixbuf = self.genpixbuf(filename, *dim)
          this.changed
          this.notify_observers
        }
      }
    end

    def self.local_path(url)
      @@l_iconring[url].synchronize{
        filename = WebIcon.get_filename(url)
        if not(FileTest.exist?(filename)) then
          begin
            res = Net::HTTP.get_response(URI.parse(url))
            if(res.is_a?(Net::HTTPResponse)) and (res.code == '200') then
              open(filename, 'wb'){ |f|
                f.write res.body
              }
            else
              filename = MUI::Skin.get("notfound.png")
            end
          rescue Timeout::Error, StandardError => e
            filename = MUI::Skin.get("notfound.png")
          end
        end
        filename
      }
    end

    def self.icondir
      if not(FileTest.exist?(File.expand_path(ICONDIR)))
        FileUtils.mkdir_p File.expand_path(ICONDIR)
      end
      ICONDIR
    end
  end
end
