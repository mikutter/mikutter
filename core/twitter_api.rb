# -*- coding: utf-8 -*-
# twitter_api.rb - Twitter API class
#
# Copyright (c) 2007, 2008 Katsuhiko Ichinose <ichi@users.sourceforge.jp>
#
# GNU General Public License version 2 is applied to this program.
#
# $Id: twitter_api.rb 164 2009-01-23 09:40:37Z ichi $
#
# customized by Toshiaki Asai
#
require 'net/http'
require 'thread'
require 'base64'
require 'io/wait'
miquire :lib, 'oauth'
miquire :core, 'environment'
miquire :core, 'plugin'
miquire :core, 'configloader'

Net::HTTP.version_1_2
=begin
class TwitterAPI
=end
class TwitterAPI < Mutex
  HOST = 'api.twitter.com'.freeze
  BASE_PATH = "http://#{HOST}/1".freeze
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 20
  FORMAT = 'json'.freeze
  API_MAX = 150
  API_RESET_INTERVAL = 3600
  OAUTH_VERSION = '1.0'.freeze
  DEFAULT_API_ARGUMENT = {:include_entities => 1}.freeze
  CACHE_EXPIRE = 60 * 60 * 24 * 2
  EXCLUDE_OPTIONS = [:cache].freeze

  include ConfigLoader

  @@failed_lock = Monitor.new
  @@last_success = nil
  @@testmode = false
  @@ntr = '200'
  @@ip_limit_reset = nil

  def initialize(a_token, a_secret, &fail_trap)
    super()
    @a_token, @a_secret = a_token, a_secret
    @getmutex = Mutex.new
    if(fail_trap) then
      @fail_trap = fail_trap
    else
      @fail_trap = nil
    end
  end

  def self.testmode
    @@testmode = true
  end

  def self.next_test_response=(ntr)
    @@ntr = ntr
  end

  def self.garbage_collect
    File.delete(*Dir.glob("#{Environment::CACHE}**#{File::Separator}*").select(&method(:is_tooold))) rescue nil end

  def self.is_tooold(file)
    Time.now - File.mtime(file) > CACHE_EXPIRE end

  SerialThread.new{ garbage_collect }

  def consumer
    OAuth::Consumer.new(Environment::TWITTER_CONSUMER_KEY,
                        Environment::TWITTER_CONSUMER_SECRET,
                        :site => 'http://twitter.com') end

  def access_token
    OAuth::AccessToken.new(consumer, @a_token, @a_secret) end

  def request_oauth_token
    consumer.get_request_token end

  def api_remain(response = nil)
    if response and response['X-RateLimit-Reset'] then
      @api_remain = [ response['X-RateLimit-Limit'].to_i,
                      response['X-RateLimit-Remaining'].to_i,
                      Time.at(response['X-RateLimit-Reset'].to_i) ]
    end
    return *@api_remain
  end

  def ip_api_remain(response = nil)
    if response and response['X-RateLimit-Reset'] then
      @ip_api_remain = [ response['X-RateLimit-Limit'].to_i,
                      response['X-RateLimit-Remaining'].to_i,
                      Time.at(response['X-RateLimit-Reset'].to_i) ]
    end
    return *@ip_api_remain
  end

  # 規制されていたらtrue
  def rate_limiting?
    limit, remain, reset = api_remain
    remain and reset and remain <= 0 and Time.new <= reset end

  def user
    nil
  end

  def connection(host = HOST)
    http = Net::HTTP.new(host)
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT
    return http
  end

  def ip_limit
    if @@ip_limit_reset
      Time.now <= @@ip_limit_reset
    end
  end

  def getopts(options)
    result = Hash.new
    result[:head] = Hash.new
    options.each_pair{ |k,v|
      case(k)
      when 'Cache'
        result[:cache] = v
      when 'Host'
        result[:host] = v
      else
        result[:head][k] = v end }
    result end

  def cacheing(path, body)
    begin
      cachefn = File::expand_path(Environment::CACHE + path)
      FileUtils.mkdir_p(File::dirname(cachefn))
      FileUtils.rm_rf(cachefn) if FileTest.exist?(cachefn) and not FileTest.file?(cachefn)
      file_put_contents(cachefn, body)
    rescue => e
      warn "cache write failed"
      warn e end end

  def cache_clear(path)
    begin
      FileUtils.rm_rf(File::expand_path(Environment::CACHE + path))
    rescue => e
      warn "cache clear failed"
      warn e end end

  def get_cache(path)
    begin
      cache_path = File::expand_path(Environment::CACHE + path)
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

  def get(path, raw_options={})
    return get_with_auth(path, raw_options) if ip_limit
    options = getopts(raw_options)
    if options[:cache]
      cache = get_cache(path)
      return cache if cache end
    res = nil
    http = nil
    begin
      http = self.connection(options[:host] || HOST)
      http.start
      res = http.get(path, options[:head])
      if res.is_a?(Net::HTTPResponse) and res.code == '200' and options.has_key?(:cache)
        cacheing(path, res.body) end
    rescue Exception => evar
      res = evar
    ensure
      begin
        http.finish if http.active?
      rescue Exception => evar
        Log.warn('TwitterAPI.get:finish') do "#{evar.inspect}" end end end
    notice "#{path} => #{res}"
    if res.is_a? Net::HTTPResponse
      limit, remain, reset = ip_api_remain(res)
      Plugin.call(:ipapiremain, remain, reset)
      if res.code == '400' or res.code == '401' or res.code == '403'
        if $debug and res.code != '400'
          Plugin.call(:update, nil, [Message.new(:message => "Request protected account without OAuth.\n#{path}\n#{options.inspect}", :system => true)]) end
        @@ip_limit_reset = reset
        return get_with_auth(path, raw_options) end
      res end end

  def get_with_auth(path, raw_options={})
    query_with_auth(:get, path, raw_options) end

  def post_with_auth(path, data={})
    query_with_auth(:post, path, data) end

  def delete_with_auth(path, raw_options={})
    query_with_auth(:delete,  path, raw_options) end

  def userstream
    begin
      access_token.method(:get).call('https://userstream.twitter.com/2/user.json',
                                     'Host' => 'userstream.twitter.com',
                                     'User-Agent' => "#{Environment::NAME}/#{Environment::VERSION}"){ |res|
        res.read_body(&Proc.new) }
    rescue Exception => evar
      warn evar end end

  def filter_stream(params={})
    begin
      callback = Proc.new
      buf = ""
      access_token.method(:get).call('http://stream.twitter.com/1/statuses/filter.' + FORMAT + get_args(params),
                                     'Host' => 'stream.twitter.com',
                                     'User-Agent' => "#{Environment::NAME}/#{Environment::VERSION}"){ |res|
        res.read_body{ |chunk|
          if chunk.split(//u)[-1] == "\n"
            callback.call(buf + chunk)
            buf.clear
          else
            buf << chunk end } }
    rescue Exception => evar
      warn evar end end

  def query_with_auth(method, path, raw_options={})
    serial = query_serial_number
    options = getopts(raw_options)
    if options[:cache] and options[:cache] != :keep
      cache = get_cache(path)
      return cache if cache end
    access_token = OAuth::AccessToken.new(consumer, @a_token, @a_secret)
    res = nil
    start_time = Time.new.freeze
    begin
      Plugin.call(:query_start,
                  :serial     => serial,
                  :method     => method,
                  :path       => path,
                  :options    => options,
                  :start_time => start_time)
      notice "request #{method} #{path}"
      begin
        res = access_token.method(method).call(BASE_PATH+path, options[:head])
      rescue Exception => evar
        res = evar end
      notice "#{method} #{path} => #{res} (#{(Time.new - start_time).to_f}s)"
      begin
        limit, remain, reset = self.api_remain(res)
        Plugin.call(:apiremain, remain, reset)
      rescue => e; end
      if res.is_a?(Net::HTTPResponse)
        if(res.code == '200')
          cacheing(path, res.body) if options.has_key?(:cache)
        elsif(res.code == '401')
          begin
            return res if(JSON.parse(res.body)["error"] == "Not authorized")
          rescue JSON::ParserError
          end
          if @fail_trap
            last_success = @@last_success
            @@failed_lock.synchronize{
              @@last_success = @fail_trap.call() if(@@last_success == last_success)
              @a_token, @a_secret, callback = *@@last_success
              callback.call if callback
              res = self.query_with_auth(method, path, raw_options) } end end end
      if res
        res
      elsif options[:cache] == :keep
        res = get_cache(path) end
    ensure
      Plugin.call(:query_end,
                  :serial     => serial,
                  :method     => method,
                  :path       => path,
                  :options    => options,
                  :start_time => start_time,
                  :end_time   => Time.new.freeze,
                  :res        => res)
    end end
  define_method(:query_serial_number, &gen_counter)

  def post(path, data, head)
    res = nil
    http = nil
    begin
      notice "post: try #{path}(#{data.inspect})"
      res = request('POST', BASE_PATH+path, data, head)
    rescue Exception => evar
      res = evar
    end
    notice "#{path} => #{res}(#{(defined?(res.body) and res.body)})"
    res
  end

  def option_since(since)
    since.httpdate =~ /^(.*?), (\S+) (\S+) (\S+) (\S+) (\S+)/
    $1+'%2C+'+$2+'+'+$3+'+'+$4+'+'+$5+'+'+$6
  end

  def public_timeline(since = nil)
    path = '/statuses/public_timeline.' + FORMAT
    path += "?since_id=#{since}" if since
    head = {'Host' => HOST}
    get(path, head)
  end

  def user_timeline(args = {})
    path = '/statuses/user_timeline.' + FORMAT + get_args(args.merge(DEFAULT_API_ARGUMENT))
    head = {'Host' => HOST}
    if (User.findbyid(args[:user_id])[:protected] rescue nil)
      get_with_auth(path, head)
    else
      get(path, head) end end

  def friends_timeline(args = {})
    path = '/statuses/home_timeline.' + FORMAT + get_args(args.merge(DEFAULT_API_ARGUMENT))
    head = {'Host' => HOST}
    get_with_auth(path, head)
  end

  def replies(args = {})
    path = '/statuses/mentions.' + FORMAT + get_args(args.merge(DEFAULT_API_ARGUMENT))
    head = {'Host' => HOST}
    get_with_auth(path, head)
  end

  def search(args = {})
    path = '/search.' + FORMAT + get_args(args.merge(DEFAULT_API_ARGUMENT))
    head = {'Host' => 'search.twitter.com'}
    get(path, head)
  end

  def trends(args = nil)
    get '/trends.' + FORMAT end

  def retweeted_to_me(args = {})
    path = "/statuses/retweeted_to_me.#{FORMAT}" + get_args(args.merge(DEFAULT_API_ARGUMENT))
    head = {'Host' => HOST}
    get_with_auth(path, head)
  end

  def retweets_of_me(args = {})
    path = "/statuses/retweets_of_me.#{FORMAT}" + get_args(args.merge(DEFAULT_API_ARGUMENT))
    head = {'Host' => HOST}
    get_with_auth(path, head)
  end

  def friendship(args = {})
    path = '/friendships/show.' + FORMAT + get_args(args)
    head = {'Host' => HOST}
    get(path, head)
  end

  def friends(args = {})
    path = '/statuses/friends.' + FORMAT
    if(args[:cache] == :keep and args[:cursor] == -1)
      FileUtils.rm_rf(Dir.glob(File::expand_path(Environment::CACHE + path) + '*')) end
    get_with_auth(path + get_args(args), head(args))
  end

  def followers(args = {})
    path = '/statuses/followers.' + FORMAT
    if(args[:cache] == :keep and args[:cursor] == -1)
      FileUtils.rm_rf(Dir.glob(File::expand_path(Environment::CACHE + path) + '*')) end
    get_with_auth(path + get_args(args), head(args))
  end

  def friends_id(args = {})
    get_with_auth('/friends/ids.' + FORMAT + get_args(args), head(args))
  end

  def followers_id(args = {})
    get_with_auth('/followers/ids.' + FORMAT + get_args(args), head(args))
  end

  def direct_messages(args = {})
    args = DEFAULT_API_ARGUMENT.merge(:skip_status => true,
                                      :count => 200).merge(args)
    get_with_auth('/direct_messages.' + FORMAT + get_args(args), head(args))
  end

  def user_show(args)
    raise if args[:id].is_a?(User)
    get("/users/show." + FORMAT + get_args(args), head(args))
  end

  def user_lookup(args)
    if args[:id].empty?
      nil
    elsif args[:id].include?(',')
      get_with_auth("/users/lookup." + FORMAT + '?user_id=' + args[:id], 'Host' => HOST)
    else
      user_show(args) end end

  def status_show(args)
    id = args[:id]
    @last_id ||= Hash.new(0)
    type_strict id => Integer
    raise "id must than 1 but specified #{id.inspect}" if id <= 0
    @status_show_mutex ||= TimeLimitedStorage.new(Integer, Mutex)
    @status_show ||= TimeLimitedStorage.new(Integer)
    atomic{ @status_show_mutex[id] ||= Mutex.new }.synchronize{
      return @status_show[id] if @status_show.has_key?(id)

      if(@last_id[id] >= 10)
        error "a lot of calls status_show/#{id}"
        pp caller
        abort
      end
      @last_id[id] += 1

      path = "/statuses/show/#{id}.#{FORMAT}" + get_args(DEFAULT_API_ARGUMENT)
      head = {'Host' => HOST, 'Cache' => true}
      result = get(path, head)
      (@status_show[id] ||= result).freeze if result.is_a?(Net::HTTPOK)
      if result.is_a?(Net::HTTPNotFound)
        notice "Status not found ##{id}."
        @status_show[id] = nil
      elsif (result.is_a? Net::HTTPBadRequest)
        @status_show[id] = nil
      elsif (result.is_a?(Net::HTTPForbidden) and JSON.parse(result.body)["error"] == 'Sorry, you are not authorized to see this status.')
        notice 'Sorry, you are not authorized to see this status.'
        @status_show[id] = nil
      end
      result } end

  def saved_searches(args=nil)
    get_with_auth('/saved_searches.' + FORMAT, head(args))
  end

  def search_create(query)
    r = post_with_auth("/saved_searches/create.#{FORMAT}",
                       :query => URI.encode(query))
    cache_clear('/saved_searches.' + FORMAT)
    r
  end

  def search_destroy(id)
    r = post_with_auth("/saved_searches/destroy/#{id}.#{FORMAT}")
    cache_clear('/saved_searches.' + FORMAT)
    r
  end

  def lists(args=nil)
    get_with_auth("/#{args[:user]}/lists." + FORMAT, head(args))
  end

  def list_subscriptions(args=nil)
    get_with_auth("/#{args[:user]}/lists/subscriptions." + FORMAT, head(args))
  end

  def list_members(args=nil)
    get_with_auth("/#{args[:user]}/#{args[:id]}/members." + FORMAT, head(args))
  end

  def list_user_followers(args=nil)
    get_with_auth("/#{args[:user]}/lists/memberships." + FORMAT, head(args))
  end

  def list_statuses(args=nil)
    if args[:mode] == :public
      get("/#{args[:user]}/lists/#{args[:id]}/statuses." + FORMAT + get_args(DEFAULT_API_ARGUMENT), head(args))
    else
      get_with_auth("/#{args[:user]}/lists/#{args[:id]}/statuses." + FORMAT, head(args)) end end

  def add_list_member(args=nil)
    post_with_auth("/#{args[:idname]}/#{args[:list_id]}/members." + FORMAT,
                   :id => args[:id],
                   :list_id => args[:list_id])
  end

  def delete_list_member(args=nil)
    post_with_auth("/#{args[:idname]}/#{args[:list_id]}/members." + FORMAT,
                   :_method => 'DELETE',
                   :id => args[:id],
                   :list_id => args[:list_id])
  end

  def rate_limit_status(args=nil)
    path = "/account/rate_limit_status.#{FORMAT}"
    head = {'Host' => HOST}
    get_with_auth(path, head)
  end

  def verify_credentials(args=nil)
    path = "/account/verify_credentials.#{FORMAT}"
    head = {'Host' => HOST}
    get_with_auth(path, head)
  end

  def head(args={})
    r = {'Host' => HOST}
    r['Cache'] = args[:cache] if args.has_key? :cache
    r
  end

  def update(status, reply_to = nil)
    args = { :status => URI.encode(status, /[^a-zA-Z0-9\'\.\-\*\(\)\_]/n) }
    args[:in_reply_to_status_id] = reply_to.to_s if reply_to
    path = '/statuses/update.' + FORMAT
    post_with_auth(path, args.merge(DEFAULT_API_ARGUMENT), head)
  end

  def retweet(msg)
    post_with_auth("/statuses/retweet/#{msg[:id]}.#{FORMAT}")
  end

  def destroy(msg)
    post_with_auth("/statuses/destroy/#{msg[:id]}.#{FORMAT}")
  end

  def send(text, user)
    enc = URI.encode(text, /[^a-zA-Z0-9\'\.\-\*\(\)\_]/n)
    path = '/direct_messages/new.' + FORMAT
    data = "user=" + URI.encode(user)
    data += "&text=" + URI.encode(enc)
    head = {'Host' => HOST}
    post_with_auth(path, data, head)
  end

  def favorite(id)
    path = "/favorites/create/#{id}." + FORMAT
    post_with_auth(path)
  end

  def unfavorite(id)
    path = "/favorites/destroy/#{id}." + FORMAT
    post_with_auth(path)
  end

  def follow(user)
    post_with_auth("/friendships/create/#{user[:id]}.#{FORMAT}")
  end

  def unfollow(user)
    post_with_auth("/friendships/destroy/#{user[:id]}.#{FORMAT}")
  end

  # list = {
  #   :user => User(自分)
  #   :name => String
  #   :description => String
  #   :public => boolean
  # }
  def add_list(list)
    type_check(list[:name] => [:respond_to?, :to_s],
               list[:description] => [:respond_to?, :to_s],
               list[:user] => [:respond_to?, :[]]){
      post_with_auth("/#{list[:user][:idname]}/lists.#{FORMAT}",
                     :name => list[:name].to_s.shrink(25),
                     :description => list[:description].to_s.shrink(100),
                     :mode => (if list[:mode] then 'public' else 'private' end)) } end

  def update_list(list)
    type_check(list => UserList) do
      self.post_with_auth("/#{list[:user][:idname]}/lists/#{list[:id]}.#{FORMAT}",
                          :name => list[:name].to_s.shrink(25),
                          :description => list[:description].to_s.shrink(100),
                          :mode => (if list[:mode] then 'public' else 'private' end)) end end

  def delete_list(list)
    query_with_auth(:delete, "/#{list[:user][:idname]}/lists/#{list[:id]}.#{FORMAT}")
  end

  if(RUBY_VERSION_ARRAY[0,2] >= [1,9])
    def get_args(args)
      if not args.empty?
        "?" + args.select{|k, v| not EXCLUDE_OPTIONS.include? k }.map{|pair| "#{URI.encode_www_form_component(pair[0].to_s).to_s}=#{URI.encode_www_form_component(pair[1].to_s).to_s}"}.join('&')
      else
        '' end end
  else
    def get_args(args)
      if not args.empty?
        "?" +  args.select{|k, v| not EXCLUDE_OPTIONS.include? k }.map{|pair| "#{URI.encode(pair[0].to_s).to_s}=#{URI.encode(pair[1].to_s).to_s}"}.join('&')
      else
        '' end end end
end
# ~> -:13: undefined method `miquire' for main:Object (NoMethodError)
