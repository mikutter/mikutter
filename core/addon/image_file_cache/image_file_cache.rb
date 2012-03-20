# -*- coding: utf-8 -*-

require 'set'

Plugin.create :image_file_cache do

  CacheWriteThread = SerialThreadGroup.new

  # appear_limit 回TLに出現したユーザはキャッシュに登録する
  # (30分ツイートしなければカウンタはリセット)
  onappear do |messages|
    messages.deach { |message|
      image_url = message.user[:profile_image_url]
      if not j_include?(image_url)
        appear_counter[image_url] ||= 0
        appear_counter[image_url] += 1
        cache_it(image_url) if(appear_counter[image_url] > appear_limit) end } end

  # キャッシュがあれば画像を返す
  filter_image_cache do |url, image, &stop|
    begin
      if j_get(url)
        path = get_local_image_name(url)
        if FileTest.exist?(path)
          body = file_get_contents(path)
          if(j_get(url)+cache_expire < Time.new)
            j_delete(url)
            FileUtils.rm(path) end
          stop.call([url, body])
        else
          j_delete(url) end end
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

  # _url_ からキャッシュを取得した日時を返す。
  # キャッシュがなければ _nil_ を返す。
  def j_get(url)
    at(:journaling_data, {})[url] end

  # _url_ のキャッシュがあれば真
  def j_include?(url)
    j_data = at(:journaling_data)
    j_data.include? url if j_data end

  # _url_ のキャッシュの日時を現在に設定する。
  def j_set(url, time = Time.now)
    atomic {
      j_data = at(:journaling_data, {}).melt
      j_data[url.freeze] = time.freeze
      store(:journaling_data, j_data)
      Reserver.new(time + cache_expire){ j_delete(url) } } end

  # _url_ のキャッシュの日時を削除する。
  def j_delete(url)
    atomic {
      j_data = at(:journaling_data)
      if j_data and j_data.include?(url)
        j_data = j_data.melt
        j_data.delete(url)
        store(:journaling_data, j_data) end } end

  def cache_it(image_url)
    notice "cache image to #{get_local_image_name(image_url)}"
    CacheWriteThread.new {
      raw = Gdk::WebImageLoader.get_raw_data(image_url)
      if(raw)
        notice "broken image. cache failed"
        j_set(image_url)
        image_dir = get_local_dir_name(image_url)
        FileUtils.mkdir_p(image_dir)
        file_put_contents(get_local_image_name(image_url), raw) end } end

  def get_local_image_name(image_url)
    image_name = Digest::MD5.hexdigest(image_url)
    File.join(get_local_dir_name(image_url, image_name), image_name) end

  def get_local_dir_name(image_url, image_name = Digest::MD5.hexdigest(image_url))
    File.expand_path(File.join(Environment::CACHE, 'icon', image_name[0], image_name[1])) end

  at(:journaling_data, {}).each { |url, time|
    Reserver.new(time + cache_expire){ j_delete(url) } }

end
