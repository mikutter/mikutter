# -*- coding: utf-8 -*-

require 'moneta'

Plugin.create :image_file_cache do

  @queue = Delayer.generate_class(priority: %i[none check_subdirs check_dirs],
                                  default: :none,
                                  expire: 0.02)
  @cache_directory = File.join(Environment::CACHE, 'image_file_cache').freeze
  @cache_journal_directory = File.join(Environment::CACHE, 'image_file_cache', 'journal').freeze
  @db = ::Moneta.build(&->(dir){ ->(this){
                                   this.use :Transformer, key: %i[md5 spread]
                                   this.adapter(:File, dir: dir)
                                 } }.(@cache_directory))
  @journal_db = ::Moneta.build(&->(dir){ ->(this){
                                           this.use :Transformer, key: %i[md5 spread], value: :marshal
                                           this.adapter(:File, dir: dir)
                                         } }.(@cache_journal_directory))
  @urls = nil

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
    body = @db[url]
    if body
      @journal_db.increment("#{url}:read_count")
      stop.call([url, body])
    end
    [url, image]
  rescue => e
    error e
    [url, image]
  end

  # キャッシュの有効期限を秒単位で返す
  def cache_expire
    (UserConfig[:image_file_cache_expire] || 32) * 24 * 60 * 60 end

  # キャッシュの容量制限を返す(Bytes)
  def cache_size_limit
    (UserConfig[:image_file_cache_size_limit] || 8) << 20 # MB単位でしか設定できないよ
  end

  # 容量オーバーの時、一度に開放する画像の最小点数
  def size_exceeded_minimum_photo_count_atonce
    128
  end

  def cache_it(photo)
    unless urls.include?(photo.uri.to_s)
      if photo.blob
        cache_blob(photo.uri.to_s, photo.blob)
      else
        photo.download.next{|downloaded|
          cache_blob(photo.uri.to_s, downloaded.blob)
        }
      end
    end
  end

  def cache_blob(uri, blob)
    return if blob.bytesize >= cache_size_limit
    SerialThread.new do
      unless urls.include?(uri)
        all_size = @journal_db.increment("all:size", blob.bytesize)
        if all_size >= cache_size_limit
          free_unused_cache
        end
        urls << uri
        @db[uri.to_s] = blob
        @journal_db["#{uri}:created"] = Time.now
        @journal_db["#{uri}:size"] = blob.bytesize
        @journal_db["all:urls"] = urls
        notice "image file cache added #{uri} (#{blob.bytesize}B, all_size: #{all_size}B)"
      end
    end
  end

  def urls
    @urls ||= Set.new(@journal_db.fetch("all:urls", []))
  end

  def free_unused_cache
    before_size = @journal_db.raw.fetch("all:size", 0).to_i
    notice "there are exists #{@urls.size} cache(s). it will delete #{[@urls.size/10, size_exceeded_minimum_photo_count_atonce].max.to_i} cache(s)."
    target_urls = @urls.to_a.sample([@urls.size/10, size_exceeded_minimum_photo_count_atonce].max.to_i)
    target_bytesize_sum = 0
    params = target_urls.map{|uri|
      count = @journal_db.raw.fetch("#{uri}:read_count", 0).to_i
      target_bytesize_sum += count
      { uri: uri,
        size: @journal_db.fetch("#{uri}:size"){ @db.fetch(uri, ''.freeze).bytesize },
        count: count }
    }
    target_bytesize_average = target_bytesize_sum.to_f / params.size
    delete_items = params.sort_by{|param| (param[:count] - target_bytesize_average) * param[:size] }.first(params.size/2)
    deleted_size = 0
    delete_items.each do |item|
      uri = item[:uri]
      notice "delete ((#{item[:count]} - #{target_bytesize_average}) * #{item[:size]} = #{(item[:count] - target_bytesize_average) * item[:size]}pts) #{uri}"
      urls.delete(uri)
      @db.delete(uri.to_s)
      @journal_db.delete("#{uri}:created")
      @journal_db.delete("#{uri}:size")
      @journal_db.raw.delete("#{uri}:read_count")
      deleted_size += item[:size]
    end
    @journal_db.decrement("all:size", deleted_size)
    @journal_db["all:urls"] = urls
    after_size = @journal_db.raw["all:size"].to_i
    notice "image file cache free. #{before_size} -> #{after_size} (#{before_size - after_size}B free)"
    activity :system, "image file cache free. #{before_size} -> #{after_size} (#{before_size - after_size}B free)"
  end

  def check_subdirs(dir)
    @queue.new(:check_subdirs) do
      Dir.foreach(dir)
        .map{|x| File.join(dir, x) }
        .select{|x| FileTest.file?(x) }
        .each{|x|
        Delayer.new(:destroy_cache, delay: (File.atime(x) rescue File.mtime(x)) + cache_expire) do
          notice "cache deleted #{x}"
          File.delete(x) if FileTest.file?(x)
          if Dir.foreach(dir).select{|y| File.file? File.join(dir, y) }.empty?
            Dir.delete(dir) rescue nil end end
      }
    end
  end

  def check_dirs(target_dir)
    @queue.new(:check_dirs) do
      Dir.foreach(target_dir)
        .select{|x| x =~ %r<\A(?:[a-fA-F0-9]{2})\Z> }
        .shuffle
        .each{|subdir|
        check_subdirs(File.join(target_dir, subdir))
      }
      Delayer.new(:destroy_cache, delay: cache_expire) do
        check_dirs(target_dir) end
    end
  end

  def _loop
    Delayer.new(:destroy_cache, delay: 60) do
      if @queue
        @queue.run
        _loop
      end
    end
  end

  on_unload do
    @db.close
    @journal_db.close
    @journal_db = @db = @queue = nil
  end

  check_dirs(@cache_directory)
  check_dirs(@cache_journal_directory)
  _loop

end
