# -*- coding: utf-8 -*-

require 'moneta'

Plugin.create :image_file_cache do

  @queue = Delayer.generate_class(priority: %i[none check_subdirs check_dirs],
                                  default: :none,
                                  expire: 0.02)
  @cache_directory = File.join(Environment::CACHE, 'image_file_cache').freeze
  @db = ::Moneta.build(&->(dir){ ->(this){
                                   this.use :Transformer, key: %i[md5 spread]
                                   this.adapter(:File, dir: dir)
                                 } }.(@cache_directory))

  on_image_file_cache_cache do |url|
    photos = Enumerator.new{|y|
      Plugin.filtering(:photo_filter, url, y)
    }
    Plugin.call(:image_file_cache_photo, photos.first)
  end

  on_image_file_cache_photo do |photo|
    cache_it(photo)
  end

  # キャッシュがあれば画像を返す
  filter_image_cache do |url, image, &stop|
    begin
      body = @db[url]
      if body
        stop.call([url, body]) end
      [url, image]
    rescue => e
      error e
      [url, image] end end

  # キャッシュの有効期限を秒単位で返す
  def cache_expire
    (UserConfig[:image_file_cache_expire] || 7) * 24 * 60 * 60 end

  def cache_it(photo)
    notice "cache added #{photo.uri}"
    photo.download.next{|downloaded|
      @db[downloaded.uri.to_s] = downloaded.blob
    }
  end

  def check_subdirs(dir)
    @queue.new(:check_subdirs) do
      Dir.foreach(dir)
        .map{|x| File.join(dir, x) }
        .select{|x| FileTest.file?(x) }
        .each{|x|
        Reserver.new((File.atime(x) rescue File.mtime(x)) + cache_expire) do
          notice "cache deleted #{x}"
          File.delete(x) if FileTest.file?(x)
          if Dir.foreach(dir).select{|y| File.file? File.join(dir, y) }.empty?
            Dir.delete(dir) rescue nil end end
      }
    end
  end

  def check_dirs
    @queue.new(:check_dirs) do
      Dir.foreach(@cache_directory)
        .select{|x| x =~ %r<\A[a-fA-F0-9]{2}\Z> }
        .shuffle
        .each{|subdir|
        check_subdirs(File.join(@cache_directory, subdir))
      }
      Reserver.new(cache_expire) do
        check_dirs end
    end
  end

  def _loop
    Reserver.new(60) do
      if @queue
        @queue.run
        _loop  end end end

  on_unload do
    @db.close
    @db = @queue = nil
  end

  check_dirs
  _loop

end
