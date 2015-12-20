# -*- coding:utf-8 -*-

miquire :core, 'user'
miquire :core, 'retriever'

require 'net/http'
require 'delegate'
miquire :lib, 'typed-array', 'timelimitedqueue'

=begin
= Message
投稿１つを表すクラス。
=end
class Message < Retriever::Model
  # screen nameにマッチする正規表現
  MentionMatcher      = /(?:@|＠|〄|☯|⑨|♨|(?:\W|^)D )([a-zA-Z0-9_]+)/.freeze

  # screen nameのみから構成される文字列から、@などを切り取るための正規表現
  MentionExactMatcher = /\A(?:@|＠|〄|☯|⑨|♨|D )?([a-zA-Z0-9_]+)\Z/.freeze

  PermalinkMatcher = Regexp.union(
    %r[\Ahttps?://twitter.com/(?:#!/)?(?<screen_name>[a-zA-Z0-9_]+)/status(?:es)?/(?<id>\d+)(?:\?.*)?\Z], # Twitter
    %r[\Ahttp://favstar\.fm/users/(?<screen_name>[a-zA-Z0-9_]+)/status/(?<id>\d+)], # Hey, Favstar. Ban stop me premiamu!
    %r[\Ahttp://aclog\.koba789\.com/i/(?<id>\d+)] # Hey, Twitter. Please BAN me rhenium!
  ).freeze

  extend Gem::Deprecate

  @@system_id = 0
  @@appear_queue = TimeLimitedQueue.new(65536, 0.1, Set){ |messages|
    Plugin.call(:appear, messages) }

  # args format
  # key     | value(class)
  #---------+--------------
  # id      | id of status(mixed)
  # entity  | entity(mixed)
  # message | posted text(String)
  # tags    | kind of message(Array)
  # user    | user who post this message(User or Hash or mixed(User IDNumber))
  # reciver | recive user(User)
  # replyto | source message(Message or mixed(Status ID))
  # retweet | retweet to this message(Message or StatusID)
  # post    | post object(Service)
  # image   | image(URL or Image object)

  self.keys = [[:id, :int, true],         # ID
               [:message, :string, true], # Message description
               [:user, User, true],       # Send by user
               [:receiver, User],         # Send to user
               [:replyto, Message],       # Reply to this message
               [:retweet, Message],       # ReTweet to this message
               [:source, :string],        # using client
               [:geo, :string],           # geotag
               [:exact, :bool],           # true if complete data
               [:created, :time],         # posted time
               [:modified, :time],        # updated time
             ]

  # appearイベント
  def self.appear(message) # :nodoc:
    @@appear_queue.push(message)
  end

  # Message.newで新しいインスタンスを作らないこと。インスタンスはコアが必要に応じて作る。
  # 検索などをしたい場合は、 _Retriever_ のメソッドを使うこと
  def initialize(value)
    type_strict value => Hash
    value.update(system) if value[:system]
    if not(value[:image].is_a?(Message::Image)) and value[:image]
      value[:image] = Message::Image.new(value[:image]) end
    super(value)
    if self[:replyto].is_a? Message
      self[:replyto].add_child(self) end
    if self[:retweet].is_a? Message
      self[:retweet].add_child(self) end
    @entity = Entity.new(self)
    Message.appear(self)
  end

  # 投稿主のidnameを返す
  def idname
    user[:idname]
  end

  # この投稿へのリプライをつぶやく
  def post(other, &proc)
    other[:replyto] = self
    other[:receiver] = self[:user]
    service = Service.primary
    if service.is_a? Service
      service.post(other){|*a| yield(*a) if block_given? } end end

  # リツイートする
  def retweet
    service = Service.primary
    if retweetable? and service
      service.retweet(self){|*a| yield(*a) if block_given? } end end

  # この投稿を削除する
  def destroy
    service = Service.primary
    if deletable? and service
      service.destroy(self){|*a| yield(*a) if block_given? } end end

  # お気に入り状態を変更する。_fav_ がtrueならお気に入りにし、falseならお気に入りから外す。
  def favorite(fav = true)
    service = Service.primary
    if favoritable? and service
      service.favorite(self, fav) end end

  # お気に入りから削除する
  def unfavorite
    favorite(false) end

  # この投稿のお気に入り状態を返す。お気に入り状態だった場合にtrueを返す
  def favorite?
    favorited_by.include?(Service.primary!.user_obj)
  rescue Service::NotExistError
    false end

  # 投稿がシステムメッセージだった場合にtrueを返す
  def system?
    self[:system]
  end

  # この投稿にリプライする権限があればtrueを返す
  def repliable?
    !!Service.primary end

  # この投稿をお気に入りに追加する権限があればtrueを返す
  def favoritable?
    Service.primary and not(system?) end
  alias favoriable? favoritable?

  # この投稿をリツイートする権限があればtrueを返す
  def retweetable?
    Service.primary and not system? and not from_me? and not protected? end

  # この投稿を削除する権限があればtrueを返す
  def deletable?
    from_me? end

  # この投稿の投稿主のアカウントの全権限を所有していればtrueを返す
  def from_me?
    return false if system?
    Service.map(&:user_obj).include?(self[:user]) end

  # この投稿が自分宛ならばtrueを返す
  def to_me?
    system? or Service.map(&:user_obj).find(&method(:receive_to?)) end

  # この投稿が公開されているものならtrueを返す。少しでも公開範囲を限定しているならfalseを返す。
  def protected?
    user.protected? end

  # この投稿の投稿主を返す
  def user
    self.get(:user, -1) end

  def service
    warn "Message#service is obsolete method. use `Service.primary'."
    Service.primary end

  # この投稿を宛てられたユーザを返す
  def receiver
    if self[:receiver].is_a? User
      self[:receiver]
    elsif self[:receiver]
      receiver_id = self[:receiver]
      self[:receiver] = parallel{
        self[:receiver] = User.findbyid(receiver_id) }
    else
      match = MentionMatcher.match(self[:message].to_s)
      if match
        result = User.findbyidname(match[1])
        self[:receiver] = result if result end end end

  # ユーザ _other_ に宛てられたメッセージならtrueを返す。
  # _other_ は、 User か_other_[:id]と_other_[:idname]が呼び出し可能なもの。
  def receive_to?(other)
    type_strict other => :[]
    (self[:receiver].is_a?(User) and other[:id] == self[:receiver][:id]) or receive_user_screen_names.include? other[:idname] end

  # このツイートが宛てられたユーザを可能な限り推測して、その idname(screen_name) を配列で返す。
  # 例えばツイート本文内に「@a @b @c」などと書かれていたら、["a", "b", "c"]を返す。
  # ==== Return
  # 宛てられたユーザの idname(screen_name) の配列
  def receive_user_screen_names
    self[:message].to_s.scan(MentionMatcher).map(&:first) end

  # 自分がこのMessageにリプライを返していればtrue
  def mentioned_by_me?
    children.any?{ |m| m.from_me? } end

  # このメッセージが何かしらの別のメッセージに宛てられたものなら真
  def has_receive_message?
    !!self[:replyto] end
  alias reply? has_receive_message?

  # このメッセージが何かに対するリツイートなら真
  def retweet?
    !!self[:retweet] end

  # この投稿が別の投稿に宛てられたものならそれを返す。
  # _force_retrieve_ がtrueなら、呼び出し元のスレッドでサーバに問い合わせるので、
  # 親投稿を受信していなくてもこの時受信できるが、スレッドがブロッキングされる。
  # falseならサーバに問い合わせずに結果を返す。
  # Messageのインスタンスかnilを返す。
  def receive_message(force_retrieve=false)
    replyto_source(force_retrieve) or retweet_source(force_retrieve) end

  def receive_message_d(force_retrieve=false)
    Thread.new{ receive_message(force_retrieve) } end

  # このMessageの宛先になっているMessageを取得して返す。
  # ==== Args
  # [force_retrieve] 真なら、ツイートがメモリ上に見つからなかった場合Twitter APIリクエストを発行する
  # ==== Return
  # Message|nil 宛先のMessage。宛先がなければnil
  def replyto_source(force_retrieve=false)
    if reply?
      result = get(:replyto, (force_retrieve ? -1 : 1))
      if result.is_a?(Message)
        result.add_child(self) unless result.children.include?(self)
        result end end end

  # replyto_source の戻り値をnextに渡すDeferredableを返す
  # ==== Args
  # [force_retrieve] 真なら、ツイートがメモリ上に見つからなかった場合Twitter APIリクエストを発行する
  # ==== Return
  # Deferredable nextの引数に宛先のMessageを渡す。宛先が無い場合は失敗し、trap{}にnilを渡す
  def replyto_source_d(force_retrieve=true)
    Thread.new do
      result = replyto_source(force_retrieve)
      if result.is_a? Message
        result
      else
        Deferred.fail(result) end end end

  # このMessageがリツイートであるなら、リツイート元のツイートを返す。
  # リツイートではないならnilを返す。リツイートであるかどうかを確認するには、
  # このメソッドの代わりに Message#retweet? を使う。
  # ==== Args
  # [force_retrieve]
  # ==== Return
  # Message|nil リツイート元のMessage。リツイートではないならnil
  def retweet_parent(force_retrieve=false)
    if retweet?
      result = get(:retweet, (force_retrieve ? -1 : 1))
      if result.is_a?(Message)
        result.add_child(self) unless result.retweeted_statuses.include?(self)
        result end end end

  # retweet_parent の戻り値をnextに渡すDeferredableを返す
  # ==== Args
  # [force_retrieve] 真なら、ツイートがメモリ上に見つからなかった場合Twitter APIリクエストを発行する
  # ==== Return
  # Deferredable nextの引数にリプライ元のMessageを渡す。リツイートではない場合は失敗し、trap{}にnilを渡す
  def retweet_parent_d(force_retrieve=true)
    Thread.new do
      result = retweet_source(force_retrieve)
      if result.is_a? Message
        result
      else
        Deferred.fail(result) end end end

  # このMessageが引用した投稿を全て返す
  # ==== Return
  # Enumerable このMessageが引用したMessageのid(Fixnum)
  def quoting_ids
    entity.lazy.select{ |entity|
      :urls == entity[:slug]
    }.map{ |entity|
      PermalinkMatcher.match(entity[:expanded_url])
    }.select(&ret_nth).map do |matched|
      matched[:id].to_i end end

  # このMessageが引用した投稿を全て返す。
  # _force_retrieve_ に真が指定されたらこのメソッドはTwitter APIをリクエストする可能性がある。
  # そのため _force_retrieve_ が真なら、Messageを取得してから返し、
  # 偽ならAPIリクエストが必要ないので、Messageオブジェクトの取得を遅延する。
  # Twitter APIリクエストを行ったがツイートが削除されていた、メモリ上に存在しないなどの理由で
  # 取得できなかったツイートに関しては、戻り値に含まれない
  # ==== Args
  # [force_retrieve] 真なら、ツイートがメモリ上に見つからなかった場合Twitter APIリクエストを発行する
  # ==== Return
  # Enumerable このMessageが引用したMessage
  def quoting_messages(force_retrieve=false)
    return @quoting_messages if defined? @quoting_messages
    if force_retrieve
      @quoting_messages ||= quoting_ids.map{|quoted_id|
        Message.findbyid(quoted_id, -1)
      }.to_a.compact.freeze.tap do |qs|
        qs.each do |q|
          q.add_quoted_by(self) end  end
    else
      quoting_ids.map{|quoted_id|
        Message.findbyid(quoted_id, 0) }.select(&ret_nth) end end

  # このMessageが引用した投稿を全て返す。
  # _force_retrieve_ に真が指定されたらこのメソッドはTwitter APIをリクエストする可能性がある。
  # Twitter APIリクエストを行ったがツイートが削除されていた、メモリ上に存在しないなどの理由で
  # 取得できなかったツイートに関しては、結果がnilとなる
  # ==== Args
  # [force_retrieve] 真なら、ツイートがメモリ上に見つからなかった場合Twitter APIリクエストを発行する
  # ==== Return
  # Deferredable
  def quoting_messages_d(force_retrieve=false)
    Thread.new{ quoting_messages(force_retrieve) } end

  # self が、何らかのツイートを引用しているなら真を返す
  # ==== Return
  # TrueClass|FalseClass
  def quoting?
    !!quoting_ids.first end

  # selfを引用しているツイート _message_ を登録する
  # ==== Args
  # [message] Message selfを引用しているMessage
  # ==== Return
  # self
  def add_quoted_by(message)
    atomic do
      @quoted_by ||= Messages.new
      unless @quoted_by.include? message
        if @quoted_by.frozen?
          @quoted_by = Messages.new(@quoted_by + [message])
        else
          @quoted_by << message end end
      self end end

  # selfを引用しているツイートを返す
  # ==== Return
  # Messages selfを引用しているMessageの配列
  def quoted_by
    if defined? @quoted_by
      @quoted_by
    else
      atomic do
        @quoted_by ||= Messages.new end end.freeze end

  # self が、何らかのツイートから引用されているなら真を返す
  # ==== Return
  # TrueClass|FalseClass
  def quoted_by?
    !quoted_by.empty? end

  # 投稿の宛先になっている投稿を再帰的にさかのぼり、それぞれを引数に取って
  # ブロックが呼ばれる。
  # _force_retrieve_ は、 Message#receive_message の引数にそのまま渡される
  def each_ancestors(force_retrieve=false, &proc)
    proc.call(self)
    parent = receive_message(force_retrieve)
    parent.each_ancestors(force_retrieve, &proc) if parent
  end

  # 投稿の宛先になっている投稿を再帰的にさかのぼり、それらを配列にして返す。
  # 配列インデックスが大きいものほど、早く投稿された投稿になる。
  # （[0]は[1]へのリプライ）
  def ancestors(force_retrieve=false)
    Enumerator.new do |yielder|
      message = self
      while message
        yielder << message
        message = message.receive_message(force_retrieve) end end end

  # 投稿の宛先になっている投稿を再帰的にさかのぼり、何にも宛てられていない投稿を返す。
  # つまり、一番祖先を返す。
  def ancestor(force_retrieve=false)
    ancestors(force_retrieve).to_a.last end

  # retweet元を再帰的に遡り、それらを配列にして返す。
  # 配列の最初の要素は必ずselfになり、以降は直前の要素のリツイート元となる。
  # ([0]は[1]へのリツイート)
  # ==== Return
  # Enumerator
  def retweet_ancestors(force_retrieve=false)
    Enumerator.new do |yielder|
      message = self
      while message
        yielder << message
        message = message.retweet_parent(force_retrieve)
      end end end

  # リツイート元を再帰的に遡り、リツイートではないツイートを返す。
  # selfがリツイートでない場合は、selfを返す。
  # ==== Args
  # [force_retrieve] 真なら、ツイートがメモリ上に見つからなかった場合Twitter APIリクエストを発行する
  # ==== Return
  # Message
  def retweet_ancestor(force_retrieve=false)
    retweet_ancestors(force_retrieve).to_a.last end

  # このMessageがリツイートなら、何のリツイートであるかを返す。
  # 返される値の retweet? は常に false になる
  # ==== Args
  # [force_retrieve] 真なら、ツイートがメモリ上に見つからなかった場合Twitter APIリクエストを発行する
  # ==== Return
  # Message|nil リツイートであればリツイート元のMessage、リツイートでなければnil
  def retweet_source(force_retrieve=false)
    if retweet?
      retweet_ancestor(force_retrieve) end end

  # retweet_source の戻り値をnextに渡すDeferredableを返す
  # ==== Args
  # [force_retrieve] 真なら、ツイートがメモリ上に見つからなかった場合Twitter APIリクエストを発行する
  # ==== Return
  # Deferredable nextの引数にリプライ元のMessageを渡す。リツイートではない場合は失敗し、trap{}にnilを渡す
  def retweet_source_d(force_retrieve=true)
    Thread.new do
      result = retweet_source(force_retrieve)
      if result.is_a? Message
        result
      else
        Deferred.fail(result) end end end

  # このMessageが属する親子ツリーに属する全てのMessageを含むSetを返す
  # ==== Args
  # [force_retrieve] 外部サーバに問い合わせる場合真
  # ==== Return
  # 関係する全てのツイート(Set)
  def around(force_retrieve = false)
    ancestor(force_retrieve).children_all end

  # この投稿に宛てられた投稿をSetオブジェクトにまとめて返す。
  def children
    @children ||= Plugin.filtering(:replied_by, self, Set.new(retweeted_statuses))[1] end

  # childrenを再帰的に遡り全てのMessageを返す
  # ==== Return
  # このMessageの子全てをSetにまとめたもの
  def children_all
    children.inject(Messages.new([self])){ |result, item| result.concat item.children_all } end

  # この投稿をお気に入りに登録したUserをSetオブジェクトにまとめて返す。
  def favorited_by
    @favorited ||= Plugin.filtering(:favorited_by, self, Set.new())[1] end

  # この投稿を「自分」がふぁぼっていれば真
  def favorited_by_me?(me = Service.services)
    case me
    when Service
      favorited_by.include? me.user_obj
    when Enumerable
      not (Set.new(favorited_by.map(&:idname)) & Set.new(me.map(&:idname))).empty?
    else
      raise ArgumentError, "first argument should be `Service' or `Enumerable'. but given `#{me.class}'" end end

  # この投稿をリツイートしたユーザを返す
  def retweeted_by
    retweeted_sources.lazy.map(&:user) end
  alias retweeted_users retweeted_by

  # この投稿に対するリツイートを返す
  def retweeted_statuses
    retweeted_sources.lazy.select{|m| m.is_a?(Message) } end

  # この投稿に対するリツイートまたはユーザを返す
  def retweeted_sources
    @retweets ||= Plugin.filtering(:retweeted_by, self, Set.new())[1].to_a.compact end

  # 選択されているユーザがこのツイートをリツイートしているなら真
  def retweeted?
    retweeted_users.include?(Service.primary!.user_obj)
  rescue Service::NotExistError
    false end

  # この投稿を「自分」がリツイートしていれば真
  def retweeted_by_me?(me = Service.services)
    case me
    when Service
      retweeted_users.include? me.user_obj
    when Enumerable
      not (Set.new(retweeted_users.map(&:idname)) & Set.new(me.map(&:idname))).empty?
    else
      raise ArgumentError, "first argument should be `Service' or `Enumerable'. but given `#{me.class}'" end end

  # この投稿をリツイート等して、 _me_ のタイムラインに出現させたリツイートを返す。
  # 特に誰もリツイートしていない場合は _self_ を返す。
  # リツイート、ふぁぼなどを行う時に使用する。
  # ==== Args
  # [me] Service 対象とするService
  # ==== Return
  # Message
  def introducer(me = Service.primary!)
    Plugin.filtering(:message_introducers, me, self, retweeted_statuses.reject{|m|m.user == me.to_user}).last.to_a.last || self
  end

  # 非公式リツイートやハッシュタグを適切に組み合わせて投稿する
  def body
    self[:message].to_s.freeze
  end

  # リンクを貼る場所とその種類を表現するEntityオブジェクトを返す
  def links
    @entity end
  alias :entity :links

  def inspect
    @value.inspect
  end

  # Message#body と同じだが、投稿制限文字数を超えていた場合には、収まるように末尾を捨てる。
  def to_s
    body[0,140].freeze end
  memoize :to_s

  def to_i
    self[:id].to_i end

  # selfを返す
  def to_message
    self end
  alias :message :to_message

  # 本文を人間に読みやすい文字列に変換する
  def to_show
    @to_show ||= body.gsub(/&(gt|lt|quot|amp);/){|m| {'gt' => '>', 'lt' => '<', 'quot' => '"', 'amp' => '&'}[$1] }.freeze end

  # このMessageのパーマリンクを取得する
  # ==== Return
  # パーマリンクのURL(String)か、存在しない場合はnil
  def perma_link
    if not system?
      "https://twitter.com/#{user[:idname]}/status/#{self[:id]}".freeze end end
  memoize :perma_link
  alias :parma_link :perma_link
  deprecate :parma_link, "perma_link", 2016, 12

  # :nodoc:
  def marshal_dump
    raise RuntimeError, 'Message cannot marshalize'
  end

  # :nodoc:
  def add_favorited_by(user, time=Time.now)
    type_strict user => User, time => Time
    return retweet_source.add_favorited_by(user, time) if retweet?
    service = Service.primary
    if service
      set_modified(time) if UserConfig[:favorited_by_anyone_age] and (UserConfig[:favorited_by_myself_age] or service.user != user.idname)
      favorited_by.add(user)
      Plugin.call(:favorite, service, user, self) end end

  # :nodoc:
  def remove_favorited_by(user)
    type_strict user => User
    return retweet_source.remove_favorited_by(user) if retweet?
    service = Service.primary
    if service
      favorited_by.delete(user)
      Plugin.call(:unfavorite, service, user, self) end end

  # :nodoc:
  def add_child(child)
    type_strict child => Message
    if child[:retweet]
      if defined? @retweets
        add_retweet_in_this_thread(child)
      else
        SerialThread.new{
          retweeted_sources
          add_retweet_in_this_thread(child) } end
    else
      if defined? @children
        add_child_in_this_thread(child)
      else
        SerialThread.new{
          children
          add_child_in_this_thread(child) } end end end

  # :nodoc:
  def add_retweet_user(retweet_user, created_at)
    type_strict retweet_user => User
    return retweet_source.add_retweet_user(retweet_user, created_at) if retweet?
    if defined? @retweets
      add_retweet_in_this_thread(retweet_user, created_at)
    else
      SerialThread.new{
        retweeted_sources
        add_retweet_in_this_thread(retweet_user, created_at) } end end

  # 最終更新日時を取得する
  def modified
    @value[:modified] ||= [self[:created], *(@retweets || []).map{ |x| x.modified }].compact.max
  end

  def inspect
    "#<#{self.class.name}: #{id} #{user.inspect} #{to_show}>"
  end

  private

  def add_retweet_in_this_thread(child, created_at=child[:created])
    type_strict child => tcor(Message, User)
    unless @retweets.include? child
      case child
      when Message
        @retweets << child
        @retweets.delete(child.user) if @retweets.include?(child.user)
      when User
        @retweets << child if retweeted_users.include?(child) end end
    service = Service.primary
    set_modified(created_at) if service and UserConfig[:retweeted_by_anyone_age] and ((UserConfig[:retweeted_by_myself_age] or service.user != child.user.idname)) end

  def add_child_in_this_thread(child)
    @children << child
  end

  def set_modified(time)
    if modified < time
      self[:modified] = time
      Plugin::call(:message_modified, self) end
    self end

  def system
    { :id => @@system_id += 1,
      :user => User.system,
      :created => Time.now } end

  #
  # Sub classes
  #

  # このツイートのユーザ情報
  class MessageUser < User
    undef_method *(public_instance_methods - [:object_id, :__send__])

    def initialize(user, raw)
      abort if not user.is_a? User
      @raw = raw.freeze
      @user = user end

    def [](key)
      @raw.has_key?(key.to_sym) ? @raw[key.to_sym] : @user[key] end

    def method_missing(*args)
      @user.__send__(*args) end end

  # 添付画像
  class Image
    attr_accessor :url
    attr_reader :resource

    IS_URL = /\Ahttps?:\/\//

    def initialize(resource)
      if(not resource.is_a?(IO)) and (FileTest.exist?(resource.to_s)) then
        @resource = open(resource)
      else
        @resource = resource
        if((IS_URL === resource) != nil) then
          @url = resource
        end
      end
    end

    def path
      if(@resource.is_a?(File)) then
        return @resource.path
      end
      return @url
    end
  end

  # 例外を引き起こした原因となるMessageをセットにして例外を発生させることができる
  class MessageError < Retriever::RetrieverError
    # messageは、Exceptionクラスと名前が被る
    attr_reader :to_message

    def initialize(body, message)
      super("#{body} occured by #{message[:id]}(#{message[:message]})")
      @to_message = message end

  end

end

class Messages < TypedArray(Message)
end

miquire :core, 'entity'
