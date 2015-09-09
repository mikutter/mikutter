# -*- coding: utf-8 -*-

require 'moneta'

module Plugin::ImageFileCache
  CacheThread = SerialThreadGroup.new
end

Plugin.create :image_file_cache do

  @queue = Delayer.generate_class(priority: %i[none check_subdirs check_dirs],
                                  default: :none,
                                  expire: 0.02)
  @cache_directory = File.join(Environment::CACHE, 'image_file_cache').freeze
  @db = ::Moneta.build(&->(dir){ ->(this){
                                   this.use :Transformer, key: %i[md5 spread]
                                   this.adapter(:File, dir: dir)
                                 } }.(@cache_directory))

  # appear_limit 回TLに出現したユーザはキャッシュに登録する
  # (30分ツイートしなければカウンタはリセット)
  on_appear do |messages|
    messages.deach do |message|
      image_url = message.user[:profile_image_url]
      if not @db.key?(image_url)
        appear_counter[image_url] ||= 0
        appear_counter[image_url] += 1
        if appear_counter[image_url] > appear_limit
          Plugin.call(:image_file_cache_cache, image_url) end end end end

  on_image_file_cache_cache do |url|
    cache_it(url) end

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

  def appear_counter
    @appear_counter ||= TimeLimitedStorage.new end

  # キャッシュする出現回数のしきい値を返す
  def appear_limit
    UserConfig[:image_file_cache_appear_limit] || 32 end

  # キャッシュの有効期限を秒単位で返す
  def cache_expire
    (UserConfig[:image_file_cache_expire] || 7) * 24 * 60 * 60 end

  def cache_it(image_url)
    Plugin::ImageFileCache::CacheThread.new do
      raw = Gdk::WebImageLoader.get_raw_data(image_url)
      if raw
        @db[image_url] = raw end end end

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
