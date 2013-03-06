# -*- coding:utf-8 -*-

require File.expand_path('utils')
miquire :core, 'user'
miquire :core, 'retriever'
miquire :core, 'messageconverters'

require 'net/http'
require 'delegate'
miquire :lib, 'typed-array', 'timelimitedqueue'

=begin
= Message
投稿１つを表すクラス。
=end
class Message < Retriever::Model
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
    if self.service
      self.service.post(other){|*a| yield *a if block_given? }
    elsif self.receive_message
      self.receive_message.post(other){|*a| yield *a if block_given? }
    end
  end

  # リツイートする
  def retweet
    if retweetable?
      self.service.retweet(self){|*a| yield *a if block_given? } if self.service end end

  # この投稿を削除する
  def destroy
    if deletable?
      self.service.destroy(self){|*a| yield *a if block_given? } if self.service end end

  # お気に入り状態を変更する。_fav_ がtrueならお気に入りにし、falseならお気に入りから外す。
  def favorite(fav = true)
    if favoritable?
      self.service.favorite(self, fav) end end

  # お気に入りから削除する
  def unfavorite
    favorite(false) end

  # この投稿のお気に入り状態を返す。お気に入り状態だった場合にtrueを返す
  def favorite?
    favorited_by.include?(Service.primary.user_obj)
  end

  # 投稿がシステムメッセージだった場合にtrueを返す
  def system?
    self[:system]
  end

  # この投稿にリプライする権限があればtrueを返す
  def repliable?
    service and self.service != nil
  end

  # この投稿をお気に入りに追加する権限があればtrueを返す
  def favoritable?
    service and not(system?) end
  alias favoriable? favoritable?

  # この投稿をリツイートする権限があればtrueを返す
  def retweetable?
    service and not system? and not from_me? end

  # この投稿を削除する権限があればtrueを返す
  def deletable?
    from_me? end

  # この投稿の投稿主のアカウントの全権限を所有していればtrueを返す
  def from_me?
    return false if not service
    return false if self.system?
    self[:user] == self.service.user if self.service end

  # この投稿が自分宛ならばtrueを返す
  def to_me?
    return true if self.system?
    if self.service
      return true if self.receive_to?(self.service.user_obj)
      return true if self[:message].to_s.include?(self.service.user.to_s)
    end
    false
  end

  # この投稿の投稿主を返す
  def user
    self.get(:user, -1) end

  # この投稿のServiceオブジェクトを返す。
  # 設定されてなければnilを返す
  def service
    if self[:post]
      self[:post]
    elsif self.receive_message
      @value[:post] = self.receive_message.service
    else
    Service.primary end end

  # この投稿を宛てられたユーザを返す
  def receiver
    if self[:receiver].is_a? User
      self[:receiver]
    elsif self[:receiver]
      receiver_id = self[:receiver]
      self[:receiver] = parallel{
        self[:receiver] = User.findbyid(receiver_id) }
    else
      match = (/@([a-zA-Z0-9_]+)/).match(self[:message].to_s)
      if match
        result = User.findbyidname(match[1])
        self[:receiver] = result if result end end end
  memoize :receiver

  # ユーザ _other_ に宛てられたメッセージならtrueを返す。
  # _other_ は、 User か_other_[:id]と_other_[:idname]が呼び出し可能なもの。
  def receive_to?(other)
    type_strict other => :[]
    if self[:receiver].is_a? User
      other[:id] == self[:receiver][:id]
    elsif self[:receiver]
      other[:id] == self[:receiver]
    else
      match = (/@([a-zA-Z0-9_]+)/).match(self[:message].to_s)
      if match
        match[1] == other[:idname] end end end

  # このツイートが宛てられたユーザを可能な限り推測して、その idname(screen_name) を配列で返す。
  # 例えばツイート本文内に「@a @b @c」などと書かれていたら、["a", "b", "c"]を返す。
  # ==== Return
  # 宛てられたユーザの idname(screen_name) の配列
  def receive_user_screen_names
    self[:message].to_s.to_enum(:each_matches, /@([a-zA-Z0-9_]+)/).map{ |m| m[1] } end

  # 自分がこのMessageにリプライを返していればtrue
  def mentioned_by_me?
    children.any?{ |m| m.from_me? } end

  # このメッセージが何かしらの別のメッセージに宛てられたものなら真
  def has_receive_message?
    self[:replyto] end

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

  def self.define_source_getter(key, condition=ret_nth, &onfound)
    define_method("#{key}_source"){ |*args|
      force_retrieve = args.first
      if(condition === self[:message].to_s)
        result = get(key, (force_retrieve ? -1 : 1))
        if result.is_a?(Message)
          onfound.call(self, result)
          result end end }
    define_method("#{key}_source_d"){ |*args|
      Thread.new{ __send__("#{key}_source", *args) } } end

  # Message#receive_message と同じ。ただし、リプライ元のみをさがす。
  define_source_getter(:replyto, /@[a-zA-Z0-9_]/){ |this, result|
    result.add_child(this) unless result.children.include?(this) }

  # Message#receive_message と同じ。ただし、ReTweetedのみをさがす。
  define_source_getter(:retweet, /^RT/){ |this, result|
    result.add_child(this) unless result.retweeted_statuses.include?(this) }

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
    parent = receive_message(force_retrieve)
    return [self, *parent.ancestors(force_retrieve)] if parent
    [self] end
  memoize :ancestors

  # 投稿の宛先になっている投稿を再帰的にさかのぼり、何にも宛てられていない投稿を返す。
  # つまり、一番祖先を返す。
  def ancestor(force_retrieve=false)
    ancestors(force_retrieve).last end

  # このMessageが属する親子ツリーに属する全てのMessageを含むSetを返す
  # ==== Args
  # [force_retrieve] 外部サーバに問い合わせる場合真
  # ==== Return
  # 関係する全てのツイート(Set)
  def around(force_retrieve = false)
    ancestor(force_retrieve).children_all end

  # この投稿に宛てられた投稿をSetオブジェクトにまとめて返す。
  def children
    @children ||= Plugin.filtering(:replied_by, self, Set.new())[1] + retweeted_statuses end

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
    not (Set.new(favorited_by.map(&:idname)) & Set.new(me.map(&:idname))).empty?
  end

  # この投稿をリツイートしたユーザを返す
  def retweeted_by
    retweeted_statuses.map{ |x| x.user }.uniq
  end

  # この投稿に対するリツイートを返す
  def retweeted_statuses
    @retweets ||= Plugin.filtering(:retweeted_by, self, Set.new)[1].select(&ret_nth) end

  # 選択されているユーザがこのツイートをリツイートしているなら真
  def retweeted?
    retweeted_by.include?(Service.primary.user_obj) end

  # この投稿を「自分」がリツイートしていれば真
  def retweeted_by_me?(me = Service.services)
    not (Set.new(retweeted_by.map(&:idname)) & Set.new(me.map(&:idname))).empty?
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
    body.gsub(/&(gt|lt|quot|amp);/){|m| {'gt' => '>', 'lt' => '<', 'quot' => '"', 'amp' => '&'}[$1] }.freeze end
  memoize :to_show

  # :nodoc:
  def marshal_dump
    raise RuntimeError, 'Message cannot marshalize'
  end

  # :nodoc:
  def add_favorited_by(user, time=Time.now)
    type_strict user => User, time => Time
    if service
      set_modified(time) if UserConfig[:favorited_by_anyone_age] and (UserConfig[:favorited_by_myself_age] or service.user != user.idname)
      favorited_by.add(user)
      Plugin.call(:favorite, service, user, self) end end

  # :nodoc:
  def remove_favorited_by(user)
    type_strict user => User
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
          retweeted_by
          add_retweet_in_this_thread(child) } end
    else
      if defined? @children
        add_child_in_this_thread(child)
      else
        SerialThread.new{
          children
          add_child_in_this_thread(child) } end end end

  # 最終更新日時を取得する
  def modified
    @value[:modified] ||= [self[:created], *(defined?(@retweets) ? @retweets : []).map{ |x| x.modified }].select(&ret_nth).max
  end

  private

  def add_retweet_in_this_thread(child)
    type_strict child => Message
    @retweets = [] if not defined? @retweets
    @retweets << child
    set_modified(child[:created]) if UserConfig[:retweeted_by_anyone_age] and ((UserConfig[:retweeted_by_myself_age] or service.user != child.user.idname)) end

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

    IS_URL = /^https?:\/\//

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
