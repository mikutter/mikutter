# -*- coding: utf-8 -*-

require 'instance_storage'

miquire :core, 'environment', 'configloader', 'userconfig', 'service_keeper'
miquire :lib, "mikutwitter", 'reserver', 'delayer'

=begin rdoc
Twitter APIとmikutterプラグインのインターフェイス
=end
class Service
  include ConfigLoader
  include InstanceStorage
  extend Enumerable

  # MikuTwitter のインスタンス
  attr_reader :twitter

  class << self

    def services_refresh
      SaveData.accounts.keys.each do |account|
        Service[account] end
      @primary = (UserConfig[:primary_account] and Service[UserConfig[:primary_account]]) or instances.first end

    # 存在するServiceオブジェクトをSetで返す。
    # つまり、投稿権限のある「自分」のアカウントを全て返す。
    alias services instances

    # Service.instances.eachと同じ
    def each(*args, &proc)
      instances.each(*args, &proc) end

    # 現在アクティブになっているサービスを返す。
    # 基本的に、あるアクションはこれが返すServiceに対して行われなければならない。
    # ==== Return
    # アクティブなServiceか、存在しない場合はnil
    def primary
      if @primary
        @primary
      elsif services.empty?
        nil
      else
        set_primary(services.first)
        @primary end end
    alias primary_service primary

    # 現在アクティブになっているサービスを返す。
    # Service.primary とちがって、サービスが一つも登録されていない時、例外を発生させる。
    # ==== Exceptions
    # Service::NotExistError :: (選択されている)Serviceが存在しない
    # ==== Return
    # アクティブなService
    def primary!
      result = primary
      raise Service::NotExistError, 'Services does not exists.' unless result
      result end

    def set_primary(service)
      type_strict service => Service
      before_primary = @primary
      return self if before_primary != @primary || @primary == service
      @primary = service
      Plugin.call(:primary_service_changed, service)
      self end

    # 新しくサービスを認証する
    def add_service(token, secret)
      type_strict token => String, secret => String

      twitter = MikuTwitter.new
      twitter.consumer_key = Environment::TWITTER_CONSUMER_KEY
      twitter.consumer_secret = Environment::TWITTER_CONSUMER_SECRET
      twitter.a_token = token
      twitter.a_secret = secret

      (twitter/:account/:verify_credentials).user.next { |user|
        id = "twitter#{user.id}".to_sym
        accounts = Service::SaveData.accounts
        if accounts.is_a? Hash
          accounts = accounts.melt
        else
          accounts = {} end
        Service::SaveData.account_register id, {
          provider: :twitter,
          slug: id,
          token: token,
          secret: secret,
          user: {
            id: user[:id],
            idname: user[:idname],
            name: user[:name],
            profile_image_url: user[:profile_image_url] } }
        service = Service[id]
        Plugin.call(:service_registered, service)
        service } end

    alias __destroy_e3de__ destroy
    def destroy(service)
      type_strict service => Service
      Service::SaveData.account_destroy service.name
      __destroy_e3de__("twitter#{service.user_obj.id}".to_sym)
      Plugin.call(:service_destroyed, service) end
    def remove_service(service)
      destroy(service) end
  end

  # プラグインには、必要なときにはこのインスタンスが渡るようになっているので、インスタンスを
  # 新たに作る必要はない
  def initialize(name)
    super
    account = Service::SaveData.account_data name
    @twitter = MikuTwitter.new
    @twitter.consumer_key = Environment::TWITTER_CONSUMER_KEY
    @twitter.consumer_secret = Environment::TWITTER_CONSUMER_SECRET
    @twitter.a_token = account[:token]
    @twitter.a_secret = account[:secret]
    Message.add_data_retriever(MessageServiceRetriever.new(self, :status_show))
    User.add_data_retriever(UserServiceRetriever.new(self, :user_show))
    Mikutter::Twitter::DirectMessage.add_data_retriever(DirectMessageRetriever.new(self, :direct_messages))
    user_initialize
  end

  # アクセストークンとアクセスキーを再設定する
  def set_token_secret(token, secret)
    Service::SaveData.account_modify name, {token: token, secret: secret}
    @twitter.a_token = token
    @twitter.a_secret = secret
    self
  end

  # 自分のUserを返す。初回はサービスに問い合せてそれを返す。
  def user_obj
    @user_obj end
  alias to_user user_obj

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
    }.terminate.trap{
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
      Plugin.call(:posted, service, [message])
      Plugin.call(:update, service, [message])
      message } }
  define_postal(:retweet){ |parent, service, options|
    parent.call(options).next{ |message|
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
    base = message.retweet? ? message[:retweet] : message
    if fav
      Plugin.call(:before_favorite, service, service.user_obj, base)
      parent.call(message).next{
        Plugin.call(:favorite, service, service.user_obj, base)
        base
      }.trap{ |e|
        Plugin.call(:fail_favorite, service, service.user_obj, base)
        Deferred.fail(e) }
    else
      service.unfavorite(message).next{
        Plugin.call(:unfavorite, service, service.user_obj, base)
        base } end }

  define_postal :unfavorite

  def inspect
    "#<Service #{idname}>" end

  def method_missing(method_name, *args)
    result = twitter.__send__(method_name, *args)
    (class << self; self end).__send__(:define_method, method_name, &twitter.method(method_name))
    result end

  private

  def user_initialize
    if defined? Service::SaveData.account_data(name.to_sym)[:user]
      @user_obj = User.new_ifnecessary(Service::SaveData.account_data(name.to_sym)[:user])
      (twitter/:account/:verify_credentials).user.next(&method(:user_data_received)).trap(&method(:user_data_failed)).terminate
    else
      res = twitter.query!('account/verify_credentials', cache: true)
      if "200" == res.code
        user_data_received(MikuTwitter::ApiCallSupport::Request::Parser.user(JSON.parse(res.body).symbolize))
      else
        user_data_failed_crash!(res) end end end

  # :enddoc:

  def user_data_received(user)
    @user_obj = user
    Service::SaveData.account_modify name, {
      user: {
        id: @user_obj[:id],
        idname: @user_obj[:idname],
        name: @user_obj[:name],
        profile_image_url: @user_obj[:profile_image_url] } } end

  def user_data_failed(exception)
    case exception
    when MikuTwitter::Error
      if not UserConfig[:verify_credentials]
        user_data_failed_crash!(exception.httpresponse) end
    else
      raise exception end end

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
        id.each_slice(100).map{|id_list|
          @post.scan(:user_lookup, id: id_list.join(','.freeze)) || [] }.flatten
      else
        @post.scan(@api, :id => id) end end end

  class DirectMessageRetriever < Service::ServiceRetriever; end

  class Error < RuntimeError; end
  class NotExistError < Error; end

  services_refresh
end

Post = Service
