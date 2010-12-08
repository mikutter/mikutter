
require File.expand_path('utils')

miquire :core, 'twitter'
miquire :core, 'environment'
miquire :core, 'user'
miquire :core, 'message'
miquire :core, 'userlist'
miquire :core, 'configloader'
miquire :core, 'userconfig'
miquire :core, "json"
miquire :core, 'delayer'

Thread.abort_on_exception = true

=begin rdoc
= Post APIレスポンスの内部表現への変換をするクラス
サーバとの通信に使うインターフェイスクラス。たいていのイベントでは、プラグインにはコアから
このインスタンスが渡されるようになっている。
=end
class Post
  include ConfigLoader

  attr_reader :twitter

  # タイムラインのキャッシュファイルのプレフィックス。
  # TIMELINE = Environment::TMPDIR + Environment::ACRO + '_timeline_cache'

  # リクエストをリトライする回数。
  # TRY_LIMIT = 5

  @@auth_confirm_func = lambda{ |service|
    begin
      request_token = service.request_oauth_token
      puts "go to #{request_token.authorize_url}"
      print "Authorized number is:"
      $stdout.flush
      access_token = request_token.get_access_token(:oauth_token => request_token.token,
                                                    :oauth_verifier => STDIN.gets.chomp)
      [access_token.token, access_token.secret]
    rescue => e
      error('invalid number')
    end
  }

  # プラグインには、必要なときにはこのインスタンスが渡るようになっているので、インスタンスを
  # 新たに作る必要はない
  def initialize
    @scaned_events = []
    @code = nil
    @twitter = Twitter.new(UserConfig[:twitter_token], UserConfig[:twitter_secret]){
      token, secret = self.class.auth_confirm_func.call(self)
      if token
        UserConfig[:twitter_token] = token
        UserConfig[:twitter_secret] = secret
      end
      @user_idname = nil
      [token, secret] }
    notice caller(1).first
    Message.add_data_retriever(MessageServiceRetriever.new(self, :status_show))
    User.add_data_retriever(UserServiceRetriever.new(self, :user_show))
  end

  # Post系APIメソッドを定義するためのメソッド。
  def self.define_postal(api, *other)
    define_postal_detail(api){|service, event, msg|
      if(event == :try)
        service.twitter.__send__(api, msg)
      elsif(event == :success and msg.is_a?(Message))
        Plugin.call(:update, service, [msg])
        Plugin.call(:posted, service, [msg]) end
    }
    define_postal(*other) if not other.empty? end

  # Post系APIの5B挙動を詳細に定義する
  def self.define_postal_detail(api, &main)
    if $quiet
      define_method(api.to_sym){ |msg|
        notice "#{api}:#{msg.inspect}"
        notice 'Actually, this post does not send.' }
    else
      define_method(api.to_sym){ |msg, &proc|
        _post(msg, api.to_sym) {|event, msg|
          if proc
            type_check(event => Symbol){ proc.call(event, msg) } end
          main.call(self, event, msg) } } end end

  # OAuth トークンを返す
  def request_oauth_token
    @twitter.request_oauth_token
  end

  # 自分のUserを返す。初回はサービスに問い合せてそれを返す。
  def user_obj
    @user_obj ||= parallel{
      scaned = scan(:verify_credentials, :no_auto_since_id => false)
      @user_obj = scaned[0] if scaned } end

  # 自分のユーザ名を返す。初回はサービスに問い合せてそれを返す。
  def user
    @user_idname ||= parallel{
      scaned = user_obj
      @user_idname = scaned[:idname] if scaned and scaned[:idname] } end
  alias :idname :user

  # userと同じだが、サービスに問い合わせずにnilを返すのでブロッキングが発生しない
  def user_by_cache
    @user_idname
  end

  # selfを返す
  def service
    self
  end

  # 認証がはじかれた場合に呼び出される関数を返す
  def self.auth_confirm_func
    return @@auth_confirm_func
  end

  # 認証がはじかれた場合に呼び出される関数を設定する。
  # ユーザに新たに認証を要求するような関数を設定する。
  def self.auth_confirm_func=(val)
    return @@auth_confirm_func = val
  end

  # サービスにクエリ _kind_ を投げる。
  # レスポンスを受け取るまでブロッキングする。
  # レスポンスを返す。失敗した場合は、apifailイベントを発生させてnilを返す。
  def scan(kind=:friends_timeline, args={})
    type_strict kind.freeze => [:respond_to?, :to_sym], args => Hash
    args = args.melt
    event_canceling = false
    if not(@scaned_events.include?(kind.to_sym)) and not(Environment::NeverRetrieveOverlappedMumble)
      event_canceling = true
    elsif not(args[:no_auto_since_id]) and not(UserConfig[:anti_retrieve_fail]) then
      since_id = at(kind.to_s + "_lastid")
      args[:since_id] = since_id if since_id
    end
    raw_text = args[:get_raw_text]
    args.delete(:no_auto_since_id)
    args.delete(:get_raw_text)
    UserConfig[:message_retry_limit].times{
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
          return result.reverse end end }
    return nil, json if raw_text end

  # scanと同じだが、別スレッドで問い合わせをするのでブロッキングしない。
  # レスポンスが帰ってきたら、渡されたブロックが呼ばれる。
  # ブロックは、必ずメインスレッドで実行されることが保証されている。
  # 問い合わせを行っているThreadを返す。
  def call_api(api, args = {})
    Thread.new{
      if args[:get_raw_text]
        res, data = scan(api.to_sym, args)
      else
        res = scan(api.to_sym, args) end
      Delayer.new{
        if args[:get_raw_text]
          yield res, data
        else
          yield res end } } end

  # フォローしている人一覧を取得する。取得したリストは、ブロックの引数として呼び出されることに注意。
  # Threadを返す。
  def followers(limit=-1, next_cursor=-1, &proc)
    following_method(:followers, limit, next_cursor, &proc) end

  # フォローしている人のID一覧を取得する。取得したリストは、ブロックの引数として呼び出されることに注意。
  # Threadを返す。
  def followers_id(limit=-1, next_cursor=-1, &proc)
    following_method(:followers_id, limit, next_cursor, &proc) end

  # フォローされている人一覧を取得する。取得したリストは、ブロックの引数として呼び出されることに注意。
  # Threadを返す。
  def followings(limit=-1, next_cursor=-1, &proc)
    following_method(:friends, limit, next_cursor, &proc) end

  # フォローされている人のID一覧を取得する。
  # 取得したリストは、ブロックの引数として呼び出されることに注意。
  # Threadを返す。
  def followings_id(limit=-1, next_cursor=-1, &proc)
    following_method(:friends_id, limit, next_cursor, &proc) end

  # 検索文字列 _q_ で、サーバ上から全てのアカウントの投稿を対象に検索する。
  # 別スレッドで実行され、結果はブロックの引数として与えられる。
  # Threadを返す。
  def search(q, args)
    args[:q] = q
    Thread.new(){
      Delayer.new(Delayer::NORMAL, scan(:search, args)){ |res|
        yield res } }
  end

  define_postal :update, :retweet, :search_create, :search_destroy, :follow, :unfollow
  define_postal :add_list_member, :delete_list_member, :add_list, :delete_list, :update_list
  alias post update

  define_postal_detail(:destroy){|service, event, msg|
    if(event == :try)
      service.twitter.destroy(msg)
    elsif(event == :success and msg.is_a?(Message))
      Plugin.call(:destroyed, [msg]) end }

  # メッセージ _message_ のお気に入りフラグを _fav_ に設定する。
  def favorite(message, fav)
    if $quiet then
      notice "fav:#{message.inspect}"
      notice 'Actually, this post does not send.'
    else
      _post(message, :status_show) {|event, msg|
        case(event)
        when :try then
          if(fav)
            twitter.favorite(msg[:id])
          else
            twitter.unfavorite(msg[:id])
          end
        when :success then
          message[:favorited] = fav
          message.__send__(fav ? :add_favorited_by : :remove_favorited_by, user_obj)
        end } end end

  def streaming(&proc)
    twitter.userstream(&proc)
  end

  def inspect
    "#<Post #{idname}>" end

  private

  def try_post(message, api)
    UserConfig[:message_retry_limit].times{ |count|
      notice "post:try:#{count}:#{message.inspect}"
      result = yield(:try, message)
      if defined?(result.code)
        if result.code == '200'
          notice "post:success:#{api}:#{count}:#{message.inspect}"
          receive = parse_json(result.body, api)
          if receive.is_a?(Array) then
            yield(:success, receive.first)
            return receive.first
          else
            yield(:success, receive)
            return receive end
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
      notice "post:fail:#{api}:#{count}:#{message.inspect}"
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

  def scan_data(kind, args)
    result = nil
    type_check(kind => [:respond_to?, :to_sym], args => Hash){
      tl = twitter.__send__(kind, args)
      if defined?(tl.code) and defined?(tl.body) then
        case(tl.code)
        when '200'
          result = tl.body
        when '400'
          limit, remain, reset = twitter.api_remain
          Plugin.call(:apilimit, reset) if(@code != tl.code)
        else
          Plugin.call(:apifail, tl.code) if(@code != tl.code) end
        @code = tl.code
      else
        Plugin.call(:apifail, (tl.methods.include?(:code) and tl.code)) end }
    return result  end

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
    parallel{
      if proc
        proc.call(query_following_method(api, limit, next_cursor))
      else
        query_following_method(api, limit, next_cursor) end } end

  def message_parser(user_retrieve)
    tclambda(Hash){ |msg|
      cnv = msg.convert_key('text' => :message,
                            'in_reply_to_user_id' => :receiver,
                            'in_reply_to_status_id' => :replyto)
      cnv[:favorited] = !!msg['favorited']
      cnv[:created] = Time.parse(msg['created_at'])
      if user_retrieve
        begin
          cnv[:user] = User.findbyid(msg['user']['id']) or scan_rule(:user_show, msg['user'])
        rescue => e
          pp msg
          error e
          abort
        end
      else
        cnv[:user] = scan_rule(:user_show, msg['user']) end
      cnv[:retweet] = scan_rule(:status_show, msg['retweeted_status']) if msg['retweeted_status']
      cnv }
  end

  def rule(kind, prop)
    (@rule ||= _gen_rule.freeze)[kind.to_sym][prop.to_sym] end

  def _gen_rule()
    shell_class = Class.new do
      def self.new_ifnecessary(arg)
        arg end end
    boolean = lambda{ |name| lambda{ |msg| msg[name] == 'true' } }
    users_parser = {
      :hasmany => 'users',
      :class => User,
      :method => :rewind,
      :proc => tclambda(Hash){ |msg|
        cnv = msg.convert_key('screen_name' =>:idname, 'url' => :url)
        cnv[:created] = Time.parse(msg['created_at'])
        cnv[:detail] = msg['description']
        cnv[:protected] = !!msg['protected']
        cnv[:followers_count] = msg['followers_count'].to_i
        cnv[:friends_count] = msg['friends_count'].to_i
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
      :proc => message_parser(false) }
    unimessage_parser = timeline_parser.clone
    unimessage_parser[:hasmany] = false
    streaming_status = unimessage_parser.clone
    streaming_status[:proc] = message_parser(true)
    search_parser = {
      :hasmany => 'results',
      :class => Message,
      :method => :new_ifnecessary,
      :proc => tclambda(Hash){ |msg|
        cnv = msg.convert_key('text' => :message,
                              'in_reply_to_user_id' => :receiver,
                              'in_reply_to_status_id' => :replyto)
        cnv[:created] = Time.parse(msg['created_at'])
        user = User.findbyidname(msg['from_user'])
        if user
          cnv[:user] = user
        else
          cnv[:user] = User.new_ifnecessary(:idname => msg['from_user'],
                                            :id => '+' + msg['from_user'],
                                            :profile_image_url => msg['profile_image_url'])
        end
        cnv } }
    saved_searches_parser = {
      :hasmany => true,
      :class => shell_class,
      :method => :new_ifnecessary,
      :proc => tclambda(Hash){ |msg| msg } }
    saved_search_parser = saved_searches_parser.clone
    saved_search_parser[:hasmany] = false
    lists_parser = {
      :hasmany => 'lists',
      :class => UserList,
      :method => :new_ifnecessary,
      :proc => tclambda(Hash){ |msg|
        cnv = msg.symbolize
        cnv[:mode] = cnv[:mode] == 'public'
        cnv[:user] = scan_rule(:user_show, cnv[:user])
        cnv } }
    list_parser = lists_parser.clone
    list_parser[:hasmany] = false
    friendship = {
      :hasmany => false,
      :class => shell_class,
      :method => :new_ifnecessary,
      :proc => tclambda(Hash){ |msg|
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
      :add_list => list_parser,
      :delete_list => list_parser,
      :update_list => list_parser,
      :add_list_member => list_parser,
      :delete_list_member => list_parser,
      :list_subscriptions => lists_parser,
      :list_members => users_list_parser,
      :list_user_followers => lists_parser,
      :list_statuses => timeline_parser,
      :streaming_status => streaming_status,
      :friendship => friendship,
      :follow => user_parser,
      :unfollow => user_parser,
    } end

  def scan_rule(rule_name, msg)
    raise ArgumentError, "should give hash but altually gave #{msg.inspect}" if not msg.is_a? Hash
    begin
      # notice msg.inspect
      param = rule(rule_name, :proc).call(msg).freeze
      # notice param.inspect
      result = rule(rule_name, :class).method(rule(rule_name, :method)).call(param)
      # notice result.inspect
      type_check(result => [:respond_to?, :merge]){
        result.merge({ :rule => rule_name,
                       :post => self,
                       :exact => true }) }
    rescue => e
      error e
      nil end end

  def parse_json(json, cache='friends_timeline', get_raw_data=false)
    if not json.nil?
      begin
        result = nil
        begin
          json = JSON.parse(json) if json.is_a?(String)
        rescue JSON::ParserError
          warn "json parse error"
          return nil end
        json.freeze
        if rule(cache, :hasmany).is_a?(String)
          tl = json[rule(cache, :hasmany)]
        elsif json.is_a?(Hash) or not rule(cache, :hasmany)
          tl = [json]
        else
          tl = json end
        return nil if not tl.respond_to?(:map)
        result = tl.map{ |msg| scan_rule(cache, msg) }.select(&ret_nth).freeze
        store(cache.to_s + "_lastid", result.first['id']) if result.first
        Delayer.new(Delayer::LAST){ Plugin.call(:appear, result) } if result.first.is_a? Message
        if get_raw_data
          return result, json
        else
          result end
      rescue => e
        error e
        nil end end end

  # :enddoc:

  class ServiceRetriever
    include Retriever::DataSource

    def initialize(post, api)
      @post = post
      @api = api
    end

    def findbyid(id)
      if id.is_a? Enumerable
        id.map(&method(:findbyid))
      else
        message = @post.scan(@api, :no_auto_since_id => true, :id => id)
        message.first if message end end

    def time
      1.0/0 end
  end

  class MessageServiceRetriever < ServiceRetriever
  end

  class UserServiceRetriever < ServiceRetriever
    include Retriever::DataSource

    def findbyid(id)
      if id.is_a? Enumerable
        # id.map{ |i| findbyid(i) }
        front = id.to_a.slice(0, 100)
        remain = id.to_a.slice(100,id.size)
        messages = @post.scan(:user_lookup, :no_auto_since_id => true, :id => front.join(','))
        messages = [] if not messages.is_a? Array
        messages.concat(findbyid(remain)) if remain and not remain.empty?
        messages
      else
        message = @post.scan(@api, :no_auto_since_id => true, :id => id)
        message.first if message end end end

end
