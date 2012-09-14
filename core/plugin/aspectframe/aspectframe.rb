# -*- coding: utf-8 -*-
require 'fileutils'

Plugin.create :aspectframe do

  PREFETCH_MONTH = 3

  if PREFETCH_MONTH == Time.new.month
    FileUtils.mkdir_p(File.expand_path(File.join(Environment::CACHE, "af")))
    # prefetch
    onappear do |messages|
      if PREFETCH_MONTH == Time.new.month
        messages.each { |message|
          if rand(10000) < Time.new.day**2 and not FileTest.exist?(localfile(message.user[:profile_image_url]))
            Gdk::WebImageLoader.get_raw_data_d(transform(message.user[:profile_image_url])).next{ |raw|
              if raw and not raw.empty?
                notice "prefetch: #{transform(message.user[:profile_image_url])}"
                SerialThread.new{
                  file_put_contents(localfile(message.user[:profile_image_url]), raw) } end
            }.terminate end } end
    end

  end

  # return fetched data
  filter_image_cache do |url, image, &stop|
    if /http:\/\/toshia.dip.jp\/img\/api\/[0-9A-F].png/ =~ url
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
    File.expand_path(File.join(Environment::CACHE, "af", "#{Digest::MD5.hexdigest(url)[0,2].upcase}.png"))
  end

  def the_day?
    time = Time.new
    4 == time.month and 1 == time.day end

end
