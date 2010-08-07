#
# post.rb
#

# タイムラインやポストを管理する

require 'utils'

miquire :core, 'twitter'
miquire :core, 'environment' # !> method redefined; discarding old sum
miquire :core, 'message'
miquire :core, 'configloader' # !> `*' interpreted as argument prefix
miquire :core, 'userconfig'
miquire :core, "json"
miquire :core, 'delayer' # !> ambiguous first argument; put parentheses or even spaces

class Post
  include ConfigLoader
 # !> ambiguous first argument; put parentheses or even spaces
  # タイムラインのキャッシュファイルのプレフィックス。
  TIMELINE = Environment::TMPDIR + Environment::ACRO + '_timeline_cache'

  # リクエストをリトライする回数。
  TRY_LIMIT = 5

  @@threads = []
  @@xml_lock = Mutex.new
  @@auth_confirm_func = lambda{ raise }

  def initialize
    @scaned_events = []
    @code = nil
    @twitter = Twitter.new(UserConfig[:twitter_token], UserConfig[:twitter_secret]){
      token, secret = self.auth_confirm_func.call(self)
      if token
        UserConfig[:twitter_token] = token
        UserConfig[:twitter_secret] = secret
      end
      store('idname', nil)
      [token, secret] }
    notice caller(1).first
    Message.add_data_retriever(MessageServiceRetriever.new(self, :status_show))
    User.add_data_retriever(UserServiceRetriever.new(self, :user_show))
  end

  def self.define_postal(api, *other)
    if $quiet # !> global variable `$quiet' not initialized
      define_method(api.to_sym){ |msg|
        notice "#{api}:#{msg.inspect}"
        notice 'Actually, this post does not send.' }
    else
      define_method(api.to_sym){ |msg, &proc|
        self._post(msg, api.to_sym) {|event, msg|
          proc.call(event, msg) if(proc)
          if(event == :try)
            twitter.__send__(api, msg)
          elsif(event == :success and msg.is_a?(Message))
            Plugin.call(:update, self, [msg]) end } }
    end
    define_postal(*other) if not other.empty? end

  def request_oauth_token
    @twitter.request_oauth_token
  end

  def user # !> `*' interpreted as argument prefix
    if at('idname')
      at('idname') # !> `*' interpreted as argument prefix
    else
      scaned = scan(:verify_credentials, :no_auto_since_id => false)
      store('idname', scaned[0][:idname]) if scaned
    end
  end
  alias :idname :user # !> `*' interpreted as argument prefix

  def user_by_cache
    at('idname')
  end # !> `*' interpreted as argument prefix

  def service
    self
  end

  def twitter
    @twitter
  end

  def auth_confirm_func
    return @@auth_confirm_func
  end

  def auth_confirm_func=(val)
    return @@auth_confirm_func = val
  end

  # twitterのタイムラインを見に行く
  def scan_data(kind, args)
    result = nil
    tl = twitter.__send__(kind, args) # !> method redefined; discarding old categories_for
    if defined?(tl.code) and defined?(tl.body) then
      case(tl.code)
      when '200'
        result = tl.body
      when '400'
        limit, remain, reset = twitter.api_remain
        Plugin.call(:apilimit, reset) if(@code != tl.code)
      else
        Plugin.call(:apifail, tl.code) if(@code != tl.code)
      end
      @code = tl.code # !> discarding old /
    else
      Plugin.call(:apifail, (tl.methods.include?(:code) and tl.code))
    end
    return result # !> discarding old /
  end

  def scan(kind=:friends_timeline, args={})
    event_canceling = false
    if not(@scaned_events.include?(kind.to_sym)) and not(Environment::NeverRetrieveOverlappedMumble) then
      event_canceling = true # !> method redefined; discarding old inspect
    elsif not(args[:no_auto_since_id]) and not(UserConfig[:anti_retrieve_fail]) then
      args[:since_id] = at(kind.to_s + "_lastid")
    end
    raw_text = args[:get_raw_text]
    args.delete(:no_auto_since_id)
    args.delete(:get_raw_text)
    data = scan_data(kind, args)
    if raw_text
      result, json = parse_json(data, kind, true)
    else
      result = parse_json(data, kind) end
    if(result)
      @scaned_events << kind.to_sym if(event_canceling)
      if raw_text
        return result.reverse, json
      else
        result.reverse end
    elsif raw_text
      return nil, json end end

  def call_api(api, args = {})
    Thread.new{
      if args[:get_raw_text]
        res, data = self.scan(api.to_sym, args)
      else
        res = self.scan(api.to_sym, args) end
      Delayer.new{
        if args[:get_raw_text]
          yield res, data
        else
          yield res end } } end

  def query_following_method(api, limit=-1, next_cursor=-1)
    if(next_cursor and next_cursor != 0 and limit != 0)
      res, raw = service.scan(api.to_sym,
                              :id => service.user,
                              :get_raw_text => true,
                              :cursor => next_cursor)
      return [] if not res
      res.reverse.concat(query_following_method(api, limit-1, raw['next_cursor']))
    else
      [] end end

  def following_method(api, limit=-1, next_cursor=-1, &proc)
    if proc
      Thread.new{
        proc.call(query_following_method(api, limit, next_cursor)) }
    else
      query_following_method(api, limit, next_cursor) end end

  def followers(limit=-1, next_cursor=-1, &proc)
    following_method(:followers, limit, next_cursor, &proc) end

  def followers_id(limit=-1, next_cursor=-1, &proc)
    following_method(:followers_id, limit, next_cursor, &proc) end

  def followings(limit=-1, next_cursor=-1, &proc)
    following_method(:friends, limit, next_cursor, &proc) end

  def followings_id(limit=-1, next_cursor=-1, &proc)
    following_method(:friends_id, limit, next_cursor, &proc) end

  def search(q, args)
    args[:q] = q
    Thread.new(){
      Delayer.new(Delayer::NORMAL, self.scan(:search, args)){ |res|
        yield res } }
  end

  def message_parser(user_retrieve)
    lambda{ |msg|
      cnv = msg.convert_key('text' => :message,
                            'in_reply_to_user_id' => :reciver,
                            'in_reply_to_status_id' => :replyto)
      cnv[:favorited] = !!msg['favorited'] # !> global variable `$daemon' not initialized
      cnv[:created] = Time.parse(msg['created_at'])
      if user_retrieve
        cnv[:user] = User.findbyid(msg['user']['id']) or self.scan_rule(:user_show, msg['user'])
      else
        cnv[:user] = self.scan_rule(:user_show, msg['user']) end
      cnv[:retweet] = self.scan_rule(:status_show, msg['retweeted_status']) if msg['retweeted_status']
      cnv }
  end

  def rule(kind, prop)
    shell_class = Class.new do def self.new_ifnecessary(arg) arg end end
    boolean = lambda{ |name| lambda{ |msg| msg[name] == 'true' } }
    users_parser = {
      :hasmany => 'users',
      :class => User,
      :method => :rewind,
      :proc => lambda{ |msg|
        cnv = msg.convert_key('screen_name' =>:idname,
                              'url' => :url) # !> `*' interpreted as argument prefix
        cnv[:created] = Time.parse(msg['created_at'])
        cnv[:detail] = msg['description']
        cnv[:protected] = !!msg['protected']
        cnv[:followers_count] = msg['followers_count'].to_i
        cnv[:friends_count] = msg['friends_count'].to_i # !> global variable `$logfile' not initialized
        cnv[:statuses_count] = msg['statuses_count'].to_i
        cnv[:notifications] = msg['notifications']
        cnv[:verified] = msg['verified']
        cnv[:following] = msg['following']
        cnv } }
    users_lookup_parser = users_parser.clone
    users_lookup_parser[:hasmany] = true
    user_parser = users_parser.clone
    user_parser[:hasmany] = false
    users_list_parser = users_parser.clone
    users_list_parser[:hasmany] = 'users'
    timeline_parser = {
      :hasmany => true,
      :class => Message,
      :method => :new_ifnecessary,
      :proc => message_parser(false) } # !> method redefined; discarding old sqrt
    unimessage_parser = timeline_parser.clone
    unimessage_parser[:hasmany] = false
    streaming_status = unimessage_parser.clone
    streaming_status[:proc] = message_parser(true)
    search_parser = {
      :hasmany => 'results',
      :class => Message,
      :method => :new_ifnecessary,
      :proc => lambda{ |msg|
        cnv = msg.convert_key('text' => :message,
                              'in_reply_to_user_id' => :reciver,
                              'in_reply_to_status_id' => :replyto)
        cnv[:created] = Time.parse(msg['created_at'])
        user = User.selectby(:idname, msg['from_user'], -2)
        if user.empty?
          cnv[:user] = User.new_ifnecessary(:idname => msg['from_user'],
                                            :id => '+' + msg['from_user'],
                                            :profile_image_url => msg['profile_image_url'])
        else
          cnv[:user] = user.first end
        cnv } }
    saved_searches_parser = {
      :hasmany => true,
      :class => shell_class,
      :method => :new_ifnecessary,
      :proc => lambda{ |msg| msg } }
    saved_search_parser = saved_searches_parser.clone
    saved_search_parser[:hasmany] = false
    lists_parser = {
      :hasmany => 'lists',
      :class => shell_class,
      :method => :new_ifnecessary,
      :proc => lambda{ |msg| msg } }
    list_parser = lists_parser.clone
    list_parser[:hasmany] = false
    friendship = {
      :hasmany => false,
      :class => shell_class,
      :method => :new_ifnecessary,
      :proc => lambda{ |msg|
        msg = msg['relationship']
        Hash[:following, msg['source']['following'],     # 自分がフォローしているか
             :followed_by, msg['source']['followed_by'], # 相手にフォローされているか
             :user, User.new_ifnecessary(:idname => msg['target']['screen_name'], # 相手
                                         :id => msg['target']['id'])] } }
    ids = {
      :hasmany => "ids",
      :class => shell_class,
      :method => :new_ifnecessary,
      :proc => lambda{|x| {:id => x} } }
    { :friends_timeline => timeline_parser,
      :user_timeline => timeline_parser,
      :replies => timeline_parser,
      :friends => users_parser,
      :followers => users_parser,
      :friends_id => ids,
      :followers_id => ids,
      :favorite => unimessage_parser,
      :unfavorite => unimessage_parser,
      :status_show => unimessage_parser,
      :user_show => user_parser,
      :user_lookup => users_lookup_parser,
      :retweeted_to_me => timeline_parser,
      :retweets_of_me => timeline_parser,
      :saved_searches => saved_searches_parser,
      :verify_credentials => user_parser,
      :update => unimessage_parser,
      :retweet => unimessage_parser,
      :destroy => unimessage_parser,
      :search_create => saved_search_parser,
      :search_destroy => saved_search_parser,
      :search => search_parser,
      :lists => lists_parser,
      :add_list_member => list_parser,
      :delete_list_member => list_parser,
      :list_subscriptions => lists_parser,
      :list_members => users_list_parser,
      :list_user_followers => lists_parser,
      :list_statuses => timeline_parser,
      :streaming_status => streaming_status,
      :friendship => friendship,
    }[kind.to_sym][prop.to_sym] end

  def scan_rule(rule, msg)
    param = self.rule(rule, :proc).call(msg)
    self.rule(rule, :class).method(self.rule(rule, :method)).call(param).merge({ :rule => rule,
                                                                                 :post => self,
                                                                                 :exact => true }) end

  def parse_json(json, cache='friends_timeline', get_raw_data=false)
    if json then
      result = nil
      json = begin
               JSON.parse(json) if json.is_a?(String)
             rescue JSON::ParserError
               warn "json parse error"
               return nil end
      json.freeze
      if self.rule(cache, :hasmany).is_a?(String)
        tl = json[self.rule(cache, :hasmany)]
      elsif not self.rule(cache, :hasmany)
        tl = [json]
      else
        tl = json end
      return nil if not tl.respond_to?(:map)
      result = tl.map{ |msg| scan_rule(cache, msg) }.freeze
      store(cache.to_s + "_lastid", result.first['id']) if result.first
      Delayer.new(Delayer::LAST){ Plugin.call(:appear, result) } if result.first.is_a? Message
      if get_raw_data
        return result, json
      else
        result end end end

  # ポストキューにポストを格納する
  define_postal :update, :retweet, :destroy, :search_create, :search_destroy, :follow, :unfollow
  define_postal :add_list_member, :delete_list_member, :delete_list
  alias post update

  def favorite(message, fav)
    if $quiet then
      notice "fav:#{message.inspect}"
      notice 'Actually, this post does not send.'
    else
      self._post(message, :status_show) {|event, msg|
        if(event == :try)
          if(fav) then
            twitter.favorite(msg[:id])
          else
            twitter.unfavorite(msg[:id]) end end } end end

  def try_post(message, api)
    UserConfig[:message_retry_limit].times{ |count|
      notice "post:try:#{count}:#{message.inspect}"
      result = yield(:try, message)
      if defined?(result.code)
        if result.code == '200'
          notice "post:success:#{count}:#{message.inspect}"
          receive = parse_json(result.body, api)
          if receive.is_a?(Array) then
            yield(:success, receive.first)
            return receive.first end
        elsif result.code[0] == '4'[0]
          begin
            errmes = JSON.parse(result.body)["error"]
            Plugin.call(:rewindstatus, "twitter 投稿エラー: #{result.code} #{errmes}")
            if errmes == "Status is a duplicate."
              yield(:success, nil)
              return true end
          rescue JSON::ParserError
          end
          if result.code == '404'
            yield(:fail, nil)
            return nil end
        elsif not(result.code[0] == '5'[0])
          yield(:fail, err)
          return nil end end
      notice "post:fail:#{count}:#{message.inspect}"
      puts result.backtrace.join("\n") if result.is_a? Exception
      yield(:retry, result)
      sleep(1) }
    yield(:fail, nil)
    return false
  end

  def _post(message, api)
    Thread.new(message){ |message|
      yield(:start, nil)
      begin
        try_post(message, api, &Proc.new)
      rescue => err
        yield(:err, err)
        yield(:fail, err)
      ensure
        yield(:exit, nil) end } end

  def marshal_dump
    raise RuntimeError, 'Post cannot marshalize'
  end

  class ServiceRetriever
    include Retriever::DataSource

    def initialize(post, api)
      @post = post
      @api = api
    end

    def findbyid(id)
      if id.is_a? Array
        id.map(&method(:findbyid))
      else
        message = @post.scan(@api, :no_auto_since_id => true, :id => id)
        message.first if message end end

#     def selectby(key, value)
#       if key.to_sym == :idname
#         @post.scan(@api, :no_auto_since_id => true, :screen_name => value)
#       else
#         [] end end

    # データの保存
    def store_datum(datum)
      false
    end

    def time
      1.0/0 end
  end

  class MessageServiceRetriever < ServiceRetriever
  end

  class UserServiceRetriever < ServiceRetriever
    include Retriever::DataSource

    def findbyid(id)
      if id.is_a? Array
        # id.map{ |i| findbyid(i) }
        front = id.slice(0, 100)
        remain = id.slice(100,id.size)
        messages = @post.scan(:user_lookup, :no_auto_since_id => true, :id => front.join(','))
        messages = [] if not messages.is_a? Array
        messages.concat(findbyid(remain)) if remain and not remain.empty?
        messages
      else
        message = @post.scan(@api, :no_auto_since_id => true, :id => id)
        message.first if message end end end

end
