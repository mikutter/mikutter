# -*- coding: utf-8 -*-
require 'fileutils'

Plugin.create :aspectframe do

  def now
    Time.new end

  THE_DAY = Time.new(now.year, 4, 1)..Time.new(now.year, 4, 2)
  PREFETCH = Time.new(now.year, 3, 30)..THE_DAY.first

  CACHE_DIR = File.expand_path(File.join(Environment::CACHE, "af"))

  if (Time.new(now.year, 3, 1)..THE_DAY.last).cover? now
    FileUtils.mkdir_p(CACHE_DIR)
    # prefetch
    onappear do |messages|
      if PREFETCH.cover?(now)
        messages.each { |message|
          if rand(1000) < Time.new.day**2 and not FileTest.exist?(localfile(message.user[:profile_image_url]))
            Gdk::WebImageLoader.get_raw_data_d(transform(message.user[:profile_image_url])).next{ |raw|
              if raw and not raw.empty?
                notice "prefetch: #{transform(message.user[:profile_image_url])}"
                SerialThread.new{
                  file_put_contents(localfile(message.user[:profile_image_url]), raw) } end
            }.terminate end } end
    end
  end
  if FileTest.exist?(CACHE_DIR) and not (PREFETCH.first..THE_DAY.last).cover?(now)
    notice 'destroy all prefetch data'
    FileUtils.rm_rf(CACHE_DIR) end

  # return fetched data
  filter_image_cache do |url, image, &stop|
    if /http:\/\/toshia.dip.jp\/img\/api\/[0-9A-F]{2}\.png/ =~ url
      local = localfile(url)
      if FileTest.exist? local
        raw = file_get_contents(local)
        if raw and not raw.empty?
          stop.call([url, raw]) end end end
    [url, image] end

  filter_web_image_loader_url_filter do |url|
    if the_day?
      [transform(url)]
    else
      [url] end end

  def transform(url)
    "http://toshia.dip.jp/img/api/#{Digest::MD5.hexdigest(url)[0,2].upcase}.png"
  end

  def localfile(url)
    File.expand_path(File.join(CACHE_DIR, "#{Digest::MD5.hexdigest(url)[0,2].upcase}_4.png"))
  end

  def the_day?
    THE_DAY.cover?(now) end

end
