# -*- coding: utf-8 -*-

require 'moneta'

module Plugin::ImageFileCache
  CacheThread = SerialThreadGroup.new
end

Plugin.create :image_file_cache do

  Delayer.new do
    @db = ::Moneta.build do
      use :Transformer, key: [:md5, :spread]
      adapter :File, dir: File.join(Environment::CACHE, 'image_file_cache')
    end
  end

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

end
