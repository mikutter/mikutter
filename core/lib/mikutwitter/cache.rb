# -*- coding: utf-8 -*-

require "mikutwitter/basic"
require "fileutils"
require 'digest/md5'

module MikuTwitter::Cache
  CACHE_EXPIRE = 60 * 60 * 24 * 2

  def cache(api, url, options, method)
    if :get == method and options[:cache]
      if(:keep == options[:cache])
        _cache_keep(api, url, options, method, &Proc.new)
      else
        _cache_get(api, url, options, method, &Proc.new) end
    else
      yield end end

  def cache_write(path, body)
    begin
      cachefn = cache_file_path(path)
      notice "write cache #{cachefn}"
      FileUtils.mkdir_p(File::dirname(cachefn))
      FileUtils.rm_rf(cachefn) if FileTest.exist?(cachefn) and not FileTest.file?(cachefn)
      file_put_contents(cachefn, body)
    rescue => e
      warn "cache write failed"
      warn e end end

  def cache_clear(path)
    begin
      FileUtils.rm_rf(cache_file_path(path))
    rescue => e
      warn "cache clear failed"
      warn e end end

  def get_cache(path)
    begin
      cache_path = cache_file_path(path)
      if FileTest.file?(cache_path)
        return Class.new{
          define_method(:body){
            file_get_contents(cache_path) }
          define_method(:code){
            '200' } }.new end
    rescue => e
      warn "cache read failed"
      warn e
      nil end end

  # パスからAPIのキャッシュファイルを返す
  # ==== Args
  # [path] APIのパス。例: "statuses/home_timeline.json?include_entities=1"
  # ==== Return
  # キャッシュファイルのローカルのパス
  def cache_file_path(path)
    cache_path = File.join(Environment::CACHE, path)
    name, query_string = *cache_path.split('?', 2)
    if(query_string)
      md5_query_string = Digest::MD5.hexdigest(query_string)
      File::expand_path("#{name}.q/#{md5_query_string[0]}/"+md5_query_string)
    else
      File::expand_path(name)
    end
  end

  def self.garbage_collect
    begin
      delete_files = Dir.glob(File.expand_path(File.join(Environment::CACHE, "**", "*"))).select(&method(:is_tooold))
      FileUtils.rm_rf(delete_files)
      delete_files
    rescue => e
      error e end end

  # キャッシュファイル _file_ が期限切れの場合真を返す。
  # ==== Args
  # [file] ファイル名
  # ==== Return
  # 削除すべきなら真
  def self.is_tooold(file)
    Time.now - File.mtime(file) > CACHE_EXPIRE end

  private
  def _cache_keep(api, url, options, method)
    path = "#{api}.json" + get_args(options)
    result = yield
    if result and '200' == result.code
      cache_write(path, result.body)
    else
      cached_value = get_cache(path)
      if cached_value
        notice "cache hit #{url}"
        return cached_value end end
    result
  rescue => e
    notice e
    cached_value = get_cache(path)
    if cached_value
      notice "cache hit #{url}"
      cached_value
    else
      raise e end end

  def _cache_get(api, url, options, method)
    path = "#{api}.json" + get_args(options)
    cached_value = get_cache(path)
    if cached_value
      notice "cache hit #{url}"
      return cached_value end
    result = yield
    if result and '200' == result.code
      cache_write(path, result.body) end
    result end

end

class MikuTwitter; include MikuTwitter::Cache end
