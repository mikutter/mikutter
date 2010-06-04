#
# post.rb
#

# タイムラインやポストを管理する

require 'utils'

miquire :core, 'twitter'
miquire :core, 'environment'
miquire :core, 'message'
miquire :core, 'configloader'
miquire :core, 'userconfig'
miquire :core, "json"
miquire :core, 'delayer'

class Post
  include ConfigLoader

  # タイムラインのキャッシュファイルのプレフィックス。
  TIMELINE = Environment::TMPDIR + Environment::ACRO + '_timeline_cache'

  # リクエストをリトライする回数。
  TRY_LIMIT = 5

  @@threads = []
  @@xml_lock = Mutex.new
  @@auth_confirm_func = lambda{ nil }

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
      [token, secret, lambda{
         if not user
           scaned = scan(:verify_credentials, :no_auto_since_id => false)
           store('idname', scaned[0][:idname]) if scaned
         end } ] }
    notice caller(1).first
    Message.add_data_retriever(ServiceRetriever.new(self, :status_show))
    User.add_data_retriever(ServiceRetriever.new(self, :user_show))
  end

  def self.define_postal(api, *other)
    define_method(api.to_sym){ |msg, &proc|
      if $quiet then
        notice "#{api}:#{msg.inspect}"
        notice 'Actually, this post does not send.'
      else
        self._post(msg, api.to_sym) {|event, msg|
          proc.call(event, msg) if(proc)
          if(event == :try)
            twitter.__send__(api, msg)
          elsif(event == :success)
            Delayer.new(Delayer::NORMAL, msg){ |msg|
              Plugin::Ring.fire(:update, [self, msg]) } end } end }
    define_postal(*other) if not other.empty? end

  def request_oauth_token
    @twitter.request_oauth_token
  end

  def user
    at('idname')
  end
  alias :idname :user

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
    tl = twitter.__send__(kind, args)
    if defined?(tl.code) and defined?(tl.body) then
      case(tl.code)
      when '200':
          result = tl.body
      when '400':
          limit, remain, reset = twitter.api_remain
          if(@code != tl.code)
            Delayer.new{
              Plugin::Ring::call(nil, :apilimit, self, reset)
            }
          end
      else
        if(@code != tl.code)
          Delayer.new{
            Plugin::Ring::call(nil, :apifail, self, tl.code) if(@code != tl.code)
          }
        end
      end
      @code = tl.code
    else
      Plugin::Ring::call(nil, :apifail, self, (tl.methods.include?(:code) and tl.code))
    end
    return result
  end

  def scan(kind=:friends_timeline, args={})
    event_canceling = false
    if not(@scaned_events.include?(kind.to_sym)) and not(Environment::NeverRetrieveOverlappedMumble) then
      event_canceling = true
    elsif not(args[:no_auto_since_id]) and not(UserConfig[:anti_retrieve_fail]) then
      args[:since_id] = at(kind.to_s + "_lastid")
    end
    args.delete(:no_auto_since_id)
    result = parse_json(scan_data(kind, args), kind)
    if(result) then
      @scaned_events << kind.to_sym if(event_canceling)
      return result.reverse
    end
  end

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
      cnv[:favorited] = !!msg['favorited']
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
      :hasmany => true,
      :class => User,
      :proc => lambda{ |msg|
        cnv = msg.convert_key('screen_name' =>:idname)
        cnv[:created] = Time.parse(msg['created_at'])
        cnv[:notifications] = msg['notifications']
        cnv[:verified] = msg['verified']
        cnv[:following] = msg['following']
        cnv } }
    user_parser = users_parser.clone
    user_parser[:hasmany] = false
    timeline_parser = {
      :hasmany => true,
      :class => Message,
      :proc => message_parser(false) }
    unimessage_parser = timeline_parser.clone
    unimessage_parser[:hasmany] = false
    streaming_status = unimessage_parser.clone
    streaming_status[:proc] = message_parser(true)
    search_parser = {
      :hasmany => 'results',
      :class => Message,
      :proc => lambda{ |msg|
        cnv = msg.convert_key('text' => :message,
                              'in_reply_to_user_id' => :reciver,
                              'in_reply_to_status_id' => :replyto)
        cnv[:created] = Time.parse(msg['created_at'])
        cnv[:user] =  User.new_ifnecessary(:idname => msg['from_user'],
                                           :id => '+' + msg['from_user'],
                                           :profile_image_url => msg['profile_image_url'])
        cnv } }
    saved_searches_parser = {
      :hasmany => true,
      :class => shell_class,
      :proc => lambda{ |msg| msg } }
    { :friends_timeline => timeline_parser,
      :replies => timeline_parser,
      :followers => users_parser,
      :friends => users_parser,
      :favorite => unimessage_parser,
      :unfavorite => unimessage_parser,
      :status_show => unimessage_parser,
      :user_show => user_parser,
      :retweeted_to_me => timeline_parser,
      :retweets_of_me => timeline_parser,
      :saved_searches => saved_searches_parser,
      :verify_credentials => user_parser,
      :update => unimessage_parser,
      :retweet => unimessage_parser,
      :destroy => unimessage_parser,
      :search_create => nil,
      :search => search_parser,
      :streaming_status => streaming_status
    }[kind.to_sym][prop.to_sym] end

  def scan_rule(rule, msg)
    param = self.rule(rule, :proc).call(msg)
    self.rule(rule, :class).new_ifnecessary(param).merge({ :rule => rule,
                                                           :post => self,
                                                           :exact => true }) end

  def parse_json(json, cache='friends_timeline')
    if json then
      result = nil
      tl = json
      begin
        tl = JSON.parse(json) if json.is_a?(String)
      rescue JSON::ParserError
        warn "json parse error"
        return nil end
      if self.rule(cache, :hasmany).is_a?(String)
        tl = tl[self.rule(cache, :hasmany)]
      elsif not self.rule(cache, :hasmany)
        tl = [tl] end
      result = tl.map{ |msg| self.scan_rule(cache, msg) }
      store(cache.to_s + "_lastid", result.first['id']) if result.first
      result end end

  # ポストキューにポストを格納する
  define_postal :update, :retweet, :destroy, :search_create
  alias post update

  def follow(user)
    if $quiet then
      notice "follow:#{user.inspect}"
      notice 'Actually, this post does not send.'
    else
      self._post(user, :user_show) {|event, user|
        twitter.follow(user) if(event == :try) } end end

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

  def _post(message, api)
    Thread.new(message){ |message|
      yield(:start, nil)
      count = 1
      begin
        loop{
          notice "post:try:#{count}:#{message.inspect}"
          result = yield(:try, message)
          if defined?(result.code)
            if result.code == '200'
              notice "post:success:#{count}:#{message.inspect}"
              receive = parse_json(result.body, api)
              if receive.is_a?(Array) then
                yield(:success, receive.first)
                break receive.first end
            elsif not(result.code[0] == '5'[0])
              yield(:fail, err)
              break end end
          notice "post:fail:#{count}:#{message.inspect}"
          yield(:retry, result)
          sleep(count)
          count += 1 }
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
      message = @post.scan(@api, :no_auto_since_id => true, :id => id)
      return message.first if message
    end

    # データの保存
    def store_datum(datum)
      false
    end
  end
end
