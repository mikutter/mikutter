# -*- coding: utf-8 -*-

require "mikutwitter/basic"
require "mikutwitter/connect"
require "mikutwitter/unauthorized"
require "mikutwitter/utils"
require "mikutwitter/cache"
require "mikutwitter/error"
require "deferred"
require "monitor"

# TwitterAPIを叩く機能
module MikuTwitter::Query

  Lock = Monitor.new

  include MikuTwitter::Utils
  include MikuTwitter::Connect
  include MikuTwitter::Unauthorized
  include MikuTwitter::Cache

  def initialize(*a, &b)
    @unretriable_uri = TimeLimitedStorage.new
    super(*a, &b) end

  # 同じURLに対して同時にリクエストを送らないように、APIのURL毎にユニークなロックを取得する
  def self.api_lock(url)
    result = Lock.synchronize{
      @url_lock ||= Hash.new{ |h, k| h[k] = Monitor.new }
      @url_lock[url] }.synchronize(&Proc.new)
    @url_lock.delete(url)
    result end

  # 別のThreadで MikuTwitter::Query#query! を実行する。
  # ==== Args
  # MikuTwitter::Query#query! と同じ
  # ==== Return
  # Deferredのインスタンス
  def api(api, options = {}, force_oauth = false)
    type_strict options => Hash
    promise = Thread.new do
      query!(api, options, force_oauth) end
    promise.abort_on_exception = false
    promise end

  # APIを叩く。OAuthを使うかどうかは自動的に判定して実行する
  # ==== Args
  # [method] メソッド。:get, :post, :put, :delete の何れか
  # [api] APIの種類（文字列）
  # [options]
  #   API引数。ただし、以下のキーは特別扱いされ、API引数からは除外される
  #   :head :: HTTPリクエストヘッダ（Hash）
  # [force_oauth] 真なら自動判別せずに必ずOAuthを使う
  # ==== Return
  # API戻り値(HTTPResponse)
  # ==== Exceptions
  # TimeoutError, MikuTwitter::Error
  def query!(api, options = {}, force_oauth = false)
    type_strict options => Hash
    method = get_api_property(api, options, method_of_api) || :get
    url = if options[:host]
            "http://#{options[:host]}/#{api}.json"
          else
            "#{@base_path}/#{api}.json" end
    res = _query!(api, options, method, url, force_oauth)
    if('2' == res.code[0])
      res
    else
      raise MikuTwitter::Error.new("#{res.code} #{res.to_s}", res) end end

  private

  # query! の本質的な部分。単純に query_with_oauth! か query_without_oauth! のどちらかを呼び出す
  def _query!(api, options, method, url, force_oauth)
    query_uri = (url + get_args(options)).freeze
    MikuTwitter::Query.api_lock(query_uri) {
      cache(api, url, options, method) {
        retry_if_fail(method, query_uri){
          fire_request_event(api, url, options, method) {
            if force_oauth or get_api_property(api, options, necessary_oauth)
              query_with_oauth!(method, url, options)
            else
              res = query_without_oauth!(method, url, options)
              if [400, 401, 403].include? res.code.to_i
                query_with_oauth!(method, url, options)
              else
                res end end } } } }
  end

  def fire_request_event(api, url, options, method)
    serial = query_serial_number
    start_time = Time.new
    output_url = url
    # output_url += get_args(options) if(:get == method)
    Plugin.call(:query_start,
                :serial     => serial,
                :method     => method,
                :path       => api,
                :options    => options,
                :start_time => start_time)
    notice "access(#{serial}): #{output_url}"
    res = yield
  ensure
    notice "quit(#{serial.to_s}): #{output_url} (#{(Time.new - start_time).to_s}s)" rescue nil
    Plugin.call(:query_end,
                :serial     => serial,
                :method     => method,
                :path       => api,
                :options    => options,
                :start_time => start_time,
                :end_time   => Time.new.freeze,
                :res        => res) end

  def retry_if_fail(method, uri)
    return @unretriable_uri[uri] if :get == method and @unretriable_uri[uri]
    res = nil
    ((UserConfig[:message_retry_limit] rescue nil) || 10).times{
      begin
        res = yield
        if res and '5' != res.code[0]
          @unretriable_uri[uri] = res if(:get == method and '4' == res.code[0])
          return res end
      rescue Net::HTTPExceptions => e
        res = e
      rescue Timeout::Error => e
        res = e end
      }
    res
  end

  define_method(:query_serial_number, &gen_counter)

  def get_api_property(api, options, apilist)
    api = api.split('/') if api.is_a? String
    path = api.empty? ? '.' : api[0]
    method = apilist.has_key?(path) ? apilist[path] : apilist['*']
    if method.is_a? Hash
      get_api_property(api[1, api.size], options, method)
    elsif method.respond_to? :call
      method.call(api, options)
    else
      method end end

  # true 必須
  # false 不要
  # ない場合(nil)は不要
  def necessary_oauth
    aster_nil = { '*' => nil }.freeze
    aster_true = { '*' => true }.freeze
    @necessary_oauth ||= {
      'statuses' => {
        'home_timeline' => true,
        'mentions' => true,
        'public_timeline' => false,
        'retweeted_by_me' => true,
        'retweeted_to_me' => true,
        'retweets_of_me' => true,
        'retweets' => aster_true,
        'destroy' => aster_true,
        'retweet' => aster_true,
        'update' => aster_true,
        'update_with_media' => aster_true,
        '*' => {
          'retweeted_by' => {
            'ids' => true } } },
      'direct_messages' => true,
      'friendships' => {
        'incoming' => true,
        'outgoing' => true,
        'create' => true,
        'destroy' => true,
        'lookup' => true,
        'update' => true,
        'no_retweet_ids' => true },
      'users' => {
        'search' => true },
      'favorites' => aster_true,
      'lists' => {
        'all' => true,
        'members' => {
          'create' => true,
          'create_all' => true,
          'destroy' => true,
          'show' => true },
        'subscribers' => {
          'create' => true,
          'show' => true,
          'destroy' => true },
        'destroy' => true,
        'update' => true,
        'create' => true },
      'account' => {
        'verify_credentials' => true,
        'end_session' => true,
        'update_profile' => true,
        'update_profile_background_image' => true,
        'update_profile_colors' => true,
        'update_profile_image' => true,
        'settings' => true,
        'totals' => true,
        'settings' => true },
      'notifications' => aster_true,
      'saved_searches' => aster_true,
      'geo' => { 'place' => true },
      'blocks' => aster_true,
      'report_spam' => true,
      'oauth' => aster_true,
    }
  end

  # get, post, put, deleteの何れかを返す。
  # nilの場合は未定義(まぁget)
  def method_of_api
    aster_post = { '*' => :post }.freeze
    create_destroy_post = { 'create' => :post, 'destroy' => :post }.freeze
    @method_of_api ||= {
      'statuses' => {
        'destroy' => :post,
        'retweet' => aster_post,
        'update' => :post,
        'update_with_media' => :post },
      'direct_messages' => {
        'destroy' => :post,
        'new' => :post },
      'friendships' => {
        'create' => :post,
        'destroy' => :post,
        'update' => :post },
      'favorites' => create_destroy_post,
      'lists' => {
        'members' => {
          'create' => :post,
          'destroy' => :post,
          'create_all' => :post },
        'subscribers' => create_destroy_post,
        'destroy' => :post,
        'update' => :post,
        'create' => :post },
      'account' => {
        'end_session' => :post,
        'update_profile' => :post,
        'update_profile_background_image' => :post,
        'update_profile_colors' => :post,
        'update_profile_image' => :post,
        'settings' => :post },
      'notifications' => aster_post,
      'saved_searches' => {
        'create' => :post,
        'destroy' => aster_post },
      'geo' => {
        'place' => :post },
      'blocks' => create_destroy_post,
      'report_spam' => :post,
      'oauth' => {
        'access_token' => :post,
        'request_token' => :post }
    }
  end

end

class MikuTwitter; include MikuTwitter::Query end
