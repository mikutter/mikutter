# -*- coding: utf-8 -*-

miquire :core, 'environment', 'user', 'message', 'userlist', 'configloader', 'userconfig'
miquire :lib, "mikutwitter", 'reserver', 'delayer', 'instance_storage'

require 'digest/md5'

Thread.abort_on_exception = true

=begin rdoc
Twitter APIとmikutterプラグインのインターフェイス
=end
class Service
  include ConfigLoader
  include InstanceStorage

  # MikuTwitter のインスタンス
  attr_reader :twitter

  @@service_lock = Mutex.new

  def self.services_refresh
    accounts = UserConfig[:accounts] # account_id => {token: ,secret:, ...}
    if not accounts
      if UserConfig[:twitter_token] and UserConfig[:twitter_secret] # 前バージョンから引継ぎ
        accounts = UserConfig[:accounts] = {
          default: {
            token: UserConfig[:twitter_token],
            secret: UserConfig[:twitter_secret],
            user: UserConfig[:verify_credentials] } }
      else
        accounts = {} end end
    accounts.keys.each do |account|
      Service[account] end
    @primary = (UserConfig[:primary_account] and Service[UserConfig[:primary_account]]) or instances.first
  end

  # 存在するServiceオブジェクトをSetで返す。
  # つまり、投稿権限のある「自分」のアカウントを全て返す。
  class << self
    alias all instances
    alias services instances
  end

  # 現在アクティブになっているサービスを返す。
  # 基本的に、あるアクションはこれが返すServiceに対して行われなければならない。
  def self.primary
    if @primary
      @primary
    else
      set_primary(services.first)
      @primary
    end
  end
  class << self; alias primary_service primary end

  def self.set_primary(service)
    type_strict service => Service
    before_primary = @primary
    @@service_lock.synchronize do
      return self if before_primary != @primary || @primary == service
      @primary = service
      Plugin.call(:primary_service_changed, service)
      self end end

  # 新しくサービスを認証する
  def self.add_service(token, secret)
    type_strict token => String, secret => String

    twitter = MikuTwitter.new
    twitter.consumer_key = Environment::TWITTER_CONSUMER_KEY
    twitter.consumer_secret = Environment::TWITTER_CONSUMER_SECRET
    twitter.a_token = token
    twitter.a_secret = secret

    (twitter/:account/:verify_credentials).user.next { |user|
      id = "twitter-#{user[:idname]}".to_sym
      accounts = UserConfig[:accounts]
      if accounts.is_a? Hash
        accounts = accounts.melt
      else
        accounts = {} end
      accounts[id] = {
        token: token,
        secret: secret,
        user: {
          id: user[:id],
          idname: user[:idname],
          name: user[:name],
          profile_image_url: user[:profile_image_url] } }
      UserConfig[:accounts] = accounts
      service = Service[id]
      Plugin.call(:service_registered, service)
      service } end

  # プラグインには、必要なときにはこのインスタンスが渡るようになっているので、インスタンスを
  # 新たに作る必要はない
  def initialize(name)
    super
    account = UserConfig[:accounts][name.to_sym]
    @twitter = MikuTwitter.new
    @twitter.consumer_key = Environment::TWITTER_CONSUMER_KEY
    @twitter.consumer_secret = Environment::TWITTER_CONSUMER_SECRET
    @twitter.a_token = account[:token]
    @twitter.a_secret = account[:secret]
    Message.add_data_retriever(MessageServiceRetriever.new(self, :status_show))
    User.add_data_retriever(UserServiceRetriever.new(self, :user_show))
    user_initialize
  end

  # アクセストークンとアクセスキーを再設定する
  def set_token_secret(token, secret)
    UserConfig[:accounts][name.to_sym] = {token: token, secret: secret}
    @twitter.a_token = token
    @twitter.a_secret = secret
    self
  end

  # 自分のUserを返す。初回はサービスに問い合せてそれを返す。
  def user_obj
    @user_obj end

  # 自分のユーザ名を返す。初回はサービスに問い合せてそれを返す。
  def user
    @user_obj[:idname] end
  alias :idname :user

  # userと同じだが、サービスに問い合わせずにnilを返すのでブロッキングが発生しない
  def user_by_cache
    @user_idname end

  # selfを返す
  def service
    self end

  # サービスにクエリ _kind_ を投げる。
  # レスポンスを受け取るまでブロッキングする。
  # レスポンスを返す。失敗した場合は、apifailイベントを発生させてnilを返す。
  # 0.1: このメソッドはObsoleteです
  def scan(kind=:friends_timeline, args={})
    no_mainthread
    wait = Queue.new
    __send__(kind, args).next{ |res|
      wait.push res
    }.terminate.trap{ |e|
      wait.push nil }
    wait.pop end

  # scanと同じだが、別スレッドで問い合わせをするのでブロッキングしない。
  # レスポンスが帰ってきたら、渡されたブロックが呼ばれる。
  # ブロックは、必ずメインスレッドで実行されることが保証されている。
  # Deferredを返す。
  # 0.1: このメソッドはObsoleteです
  def call_api(api, args = {}, &proc)
    __send__(api, args).next &proc end

  # Streaming APIに接続する
  def streaming(method = :userstream, *args, &proc)
    twitter.__send__(method, *args, &proc) end

  #
  # POST関連
  #

  # なんかコールバック機能つける
  # Deferred返すから無くてもいいんだけどねー
  def self.define_postal(method, twitter_method = method, &wrap)
    function = lambda{ |api, options, &callback|
      if(callback)
        callback.call(:start, options)
        callback.call(:try, options)
        api.call(options).next{ |res|
          callback.call(:success, res)
          res
        }.trap{ |exception|
          callback.call(:err, exception)
          callback.call(:fail, exception)
          callback.call(:exit, nil)
          Deferred.fail(exception)
        }.next{ |val|
          callback.call(:exit, nil)
          val }
      else
        api.call(options) end }
    if block_given?
      define_method(method){ |*args, &callback|
        wrap.call(lambda{ |options|
               function.call(twitter.method(twitter_method), options, &callback) }, self, *args) }
    else
      define_method(method){ |options, &callback| function.call(twitter.method(twitter_method), options, &callback) } end
  end

  define_postal(:update){ |parent, service, options|
    parent.call(options).next{ |message|
      notice 'event fire :posted and :update by statuses/update'
      Plugin.call(:posted, service, [message])
      Plugin.call(:update, service, [message])
      message } }
  define_postal(:retweet){ |parent, service, options|
    parent.call(options).next{ |message|
      notice 'event fire :posted and :update by statuses/retweet'
      Plugin.call(:posted, service, [message])
      Plugin.call(:update, service, [message])
      message } }
  define_postal :search_create
  define_postal :search_destroy
  define_postal :follow
  define_postal :unfollow
  define_postal :add_list_member
  define_postal :delete_list_member
  define_postal :add_list
  define_postal :delete_list
  define_postal :update_list
  define_postal :send_direct_message
  define_postal :destroy_direct_message
  define_postal(:destroy){ |parent, service, options|
    parent.call(options).next{ |message|
      message[:rule] = :destroy
      Plugin.call(:destroyed, [message])
      message } }
  alias post update

  define_postal(:favorite) { |parent, service, message, fav = true|
    if fav
      Plugin.call(:before_favorite, service, service.user_obj, message)
      parent.call(message).next{ |message|
        Plugin.call(:favorite, service, service.user_obj, message)
        message
      }.trap{ |e|
        Plugin.call(:fail_favorite, service, service.user_obj, message)
        Deferred.fail(e) } else
      service.unfavorite(message).next{ |message|
        Plugin.call(:unfavorite, service, service.user_obj, message)
        message } end }

  define_postal :unfavorite

  def inspect
    "#<Service #{idname}>" end

  def method_missing(method_name, *args)
    result = twitter.__send__(method_name, *args)
    (class << self; self end).__send__(:define_method, method_name, &twitter.method(method_name))
    result end

  private

  def user_initialize
    if defined? UserConfig[:accounts][name.to_sym][:user]
      @user_obj = User.new_ifnecessary(UserConfig[:accounts][name.to_sym][:user])
      (twitter/:account/:verify_credentials).user.next(&method(:user_data_received)).trap(&method(:user_data_failed))
    else
      res = twitter.query!('account/verify_credentials', cache: true)
      if "200" == res.code
        user_data_received(MikuTwitter::ApiCallSupport::Request::Parser.user(JSON.parse(res.body).symbolize))
      else
        user_data_failed_crash!(res) end end end

  # :enddoc:

  def user_data_received(user)
    @user_obj = user
    accounts = UserConfig[:accounts]
    if accounts.is_a? Hash
      accounts = accounts.melt
      accounts[name.to_sym] ||= {}
    else
      accounts = {name.to_sym => {}} end
    accounts[name.to_sym][:user] = {
      id: @user_obj[:id],
      idname: @user_obj[:idname],
      name: @user_obj[:name],
      profile_image_url: @user_obj[:profile_image_url] }
    UserConfig[:accounts] = accounts
  end

  def user_data_failed(e)
    if e.is_a? MikuTwitter::Error
      if not UserConfig[:verify_credentials]
        user_data_failed_crash!(e.httpresponse) end end end

  def user_data_failed_crash!(res)
    if '400' == res.code
      chi_fatal_alert "起動に必要なデータをTwitterが返してくれませんでした。規制されてるんじゃないですかね。\n" +
        "ニコ動とか見て、規制が解除されるまで適当に時間を潰してください。ヽ('ω')ﾉ三ヽ('ω')ﾉもうしわけねぇもうしわけねぇ\n" +
        "\n\n--\n\n" +
        "#{res.code} #{res.body}"
    else
      chi_fatal_alert "起動に必要なデータをTwitterが返してくれませんでした。電車が止まってるから会社行けないみたいなかんじで起動できません。ヽ('ω')ﾉ三ヽ('ω')ﾉもうしわけねぇもうしわけねぇ\n"+
        "Twitterサーバの情況を調べる→ https://dev.twitter.com/status\n"+
        "Twitterサーバの情況を調べたくない→ http://www.nicovideo.jp/vocaloid\n\n--\n\n" +
        "#{res.code} #{res.body}" end end

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
        @post.scan(@api, :id => id) end end

    def time
      1.0/0 end
  end

  class MessageServiceRetriever < ServiceRetriever
  end

  class UserServiceRetriever < ServiceRetriever
    include Retriever::DataSource

    def findbyid(id)
      if id.is_a? Enumerable
        front = id.to_a.slice(0, 100)
        remain = id.to_a.slice(100,id.size)
        messages = @post.scan(:user_lookup, :id => front.join(','))
        messages = Messages.new if not messages.is_a? Array
        messages += findbyid(remain) if remain and not remain.empty?
        messages
      else
        @post.scan(@api, :id => id) end end end

  services_refresh
end

Post = Service
