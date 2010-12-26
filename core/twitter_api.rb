#
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
miquire :lib, 'escape'
miquire :lib, 'oauth'
miquire :plugin, 'plugin'

Net::HTTP.version_1_2
=begin
class TwitterAPI
=end
class TwitterAPI < Mutex
  HOST = 'api.twitter.com'
  BASE_PATH = "http://#{HOST}/1"
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 20
  FORMAT = 'json'
  API_MAX = 150
  API_RESET_INTERVAL = 3600
  OAUTH_VERSION = '1.0'

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
      cachefn = File::expand_path(Config::CACHE + path)
      FileUtils.mkdir_p(File::dirname(cachefn))
      FileUtils.rm_rf(cachefn) if FileTest.exist?(cachefn) and not FileTest.file?(cachefn)
      file_put_contents(cachefn, body)
    rescue => e
      warn "cache write failed"
      warn e end end

  def cache_clear(path)
    begin
      FileUtils.rm_rf(File::expand_path(Config::CACHE + path))
    rescue => e
      warn "cache clear failed"
      warn e end end

  def get_cache(path)
    begin
      cache_path = File::expand_path(Config::CACHE + path)
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

  def get(path, raw_options)
    options = getopts(raw_options)
    if options[:cache]
      cache = get_cache(path)
      return cache if cache end
    return get_with_auth(path, raw_options) if ip_limit
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
      if res.code == '400'
        @@ip_limit_reset = reset # Time.at(res['X-RateLimit-Reset'].to_i)
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
      warn evar
    end
  end

  def query_with_auth(method, path, raw_options={})
    if Thread.current == Thread.main
      if $debug
        raise "called by main thread: #{method} #{path}"
      else
        warn "called by main thread: #{method} #{path}" end end
    options = getopts(raw_options)
    if options[:cache]
      cache = get_cache(path)
      return cache if cache end
    access_token = OAuth::AccessToken.new(consumer, @a_token, @a_secret)
    res = nil
    begin
      res = access_token.method(method).call(BASE_PATH+path, options[:head])
    rescue Exception => evar
      res = evar end
    notice "#{method} #{path} => #{res}"
    if res.is_a?(Net::HTTPResponse)
      limit, remain, reset = self.api_remain(res)
      if(res.code == '200')
        cacheing(path, res.body) if options.has_key?(:cache)
        Plugin.call(:apiremain, remain, reset)
      elsif(res.code == '401')
        if @fail_trap
          last_success = @@last_success
          @@failed_lock.synchronize{
            @@last_success = @fail_trap.call() if(@@last_success == last_success)
            @a_token, @a_secret, callback = *@@last_success
            callback.call if callback
            res = self.query_with_auth(method, path, raw_options) } end end end
    res end

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
    path = '/statuses/user_timeline.' + FORMAT + get_args(args)
    head = {'Host' => HOST}
    get(path, head) end

  def friends_timeline(args = {})
    path = '/statuses/home_timeline.' + FORMAT + get_args(args)
    head = {'Host' => HOST}
    get_with_auth(path, head)
  end

  def replies(args = {})
    path = '/statuses/mentions.' + FORMAT + get_args(args)
    head = {'Host' => HOST}
    get_with_auth(path, head)
  end

  def search(args = {})
    path = '/search.' + FORMAT + get_args(args)
    head = {'Host' => 'search.twitter.com'}
    get(path, head)
  end

  def retweeted_to_me(args = {})
    path = "/statuses/retweeted_to_me.#{FORMAT}" + get_args(args)
    head = {'Host' => HOST}
    get_with_auth(path, head)
  end

  def retweets_of_me(args = {})
    path = "/statuses/retweets_of_me.#{FORMAT}" + get_args(args)
    head = {'Host' => HOST}
    get_with_auth(path, head)
  end

  def friendship(args = {})
    path = '/friendships/show.' + FORMAT + get_args(args)
    head = {'Host' => HOST}
    get(path, head)
  end

  def friends(args = {})
    path = '/statuses/friends.' + FORMAT + get_args(args)
    get(path, head(args))
  end

  def followers(args = {})
    path = '/statuses/followers.' + FORMAT + get_args(args)
    get(path, head(args))
  end

  def friends_id(args = {})
    get('/friends/ids.' + FORMAT + get_args(args), head(args))
  end

  def followers_id(args = {})
    get('/followers/ids.' + FORMAT + get_args(args), head(args))
  end

  def direct_messages(since = nil)
    path = '/direct_messages.' + FORMAT
    path += "?since=#{option_since(since)}" if since
    head = {'Host' => HOST}
    get_with_auth(path, head)
  end

  def user_show(args)
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
    path = "/statuses/show/#{args[:id]}.#{FORMAT}"
    head = {'Host' => HOST}
    get(path, head)
  end

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
      get("/#{args[:user]}/lists/#{args[:id]}/statuses." + FORMAT, head(args))
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
    path = '/statuses/update.' + FORMAT
    enc = URI.encode(status, /[^a-zA-Z0-9\'\.\-\*\(\)\_]/n)
    data = 'status=' + enc
    data += '&in_reply_to_status_id=' + reply_to.to_s if reply_to
    # data += '&source=' + PROG_NAME
    head = {'Host' => HOST}
    post_with_auth(path, data, head)
  end

  def retweet(msg)
    post_with_auth("/statuses/retweet/#{msg[:id]}.#{FORMAT}")
  end

  def destroy(msg)
    post_with_auth("/statuses/destroy/#{msg[:id]}.#{FORMAT}")
  end

  def send(user, text)
    path = '/direct_messages/new.' + FORMAT
    data = "user=" + URI.encode(user)
    data += "&text=" + URI.encode(text)
    data += '&source=' + PROG_NAME
    head = {'Host' => HOST}
    res = post_with_auth(path, data)
    res
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

  def get_args(args)
    if not args.empty?
      "?" + args.map{|k, v| "#{Escape.uri_segment(k.to_s).to_s}=#{Escape.uri_segment(v.to_s).to_s}"}.join('&')
    else
      ''
    end
  end
end
# ~> -:13: undefined method `miquire' for main:Object (NoMethodError)
