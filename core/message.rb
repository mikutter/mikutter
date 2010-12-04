# -*- coding:utf-8 -*-

require File.expand_path('utils')
miquire :core, 'autotag'
miquire :core, 'user'
miquire :core, 'retriever'

require 'net/http'

=begin
= Message
投稿１つを表すクラス。
=end
class Message < Retriever::Model
  @@system_id = 0

  # args format
  # key     | value(class)
  #---------+--------------
  # id      | id of status(mixed)
  # message | posted text(String)
  # tags    | kind of message(Array)
  # user    | user who post this message(User or Hash or mixed(User IDNumber))
  # reciver | recive user(User)
  # replyto | source message(Message or mixed(Status ID))
  # retweet | retweet to this message(Message or StatusID)
  # post    | post object(Post)
  # image   | image(URL or Image object)
  # xml     | source xml text

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

  # Message.newで新しいインスタンスを作らないこと。インスタンスはコアが必要に応じて作る。
  # 検索などをしたい場合は、 _Retriever_ のメソッドを使うこと
  def initialize(value)
    assert_type(Hash, value)
    value.update(system) if value[:system]
    if not(value[:image].is_a?(Message::Image)) and value[:image]
      value[:image] = Message::Image.new(value[:image]) end
    super(value)
    if self[:replyto].is_a? Message
      self[:replyto].add_child(self) end
    if self[:retweet].is_a? Message
      self[:retweet].add_child(self) end
    if UserConfig[:shrinkurl_expand] and MessageConverters.shrinkable_url_regexp === value[:message]
      self[:message] = MessageConverters.expand_url_all(value[:message]) end end

  # 投稿主のidnameを返す
  def idname
    self[:user][:idname]
  end

  # この投稿へのリプライをつぶやく
  def post(other, &proc)
    other[:replyto] = self
    other[:receiver] = self[:user]
    if self.service then
      self.service.post(other){|*a| yield *a }
    elsif self.receive_message then
      self.receive_message.post(other){|*a| yield *a }
    end
  end

  # リツイートする
  def retweet
    self.service.retweet(self){|*a| yield *a if block_given? } if self.service
  end

  # この投稿を削除する
  def destroy
    self.service.destroy(self){|*a| yield *a if block_given? } if self.service
  end

  # お気に入り状態を変更する。_fav_ がtrueならお気に入りにし、falseならお気に入りから外す。
  def favorite(fav)
    self.service.favorite(self, fav)
  end

  # この投稿のお気に入り状態を返す。お気に入り状態だった場合にtrueを返す
  def favorite?
    if self[:favorited].is_a?(String) then
      self[:favorited] = self[:favorited] == 'true'
    else
      self[:favorited] == true
    end
  end

  # この投稿をお気に入りに追加する権限があればtrueを返す。
  def favoriable?
    not system?
  end

  # obsolete
  # def <<(msg)
  #   if (msg.instance_of Symbol)
  #     self[:tags] << msg
  #   else
  #     self[:message] << msg
  #   end
  # end

  # 投稿がシステムメッセージだった場合にtrueを返す
  def system?
    self[:system]
  end

  # この投稿にリプライする権限があればtrueを返す
  def repliable?
    self.service != nil
  end

  # この投稿の投稿主のアカウントの全権限を所有していればtrueを返す
  def from_me?
    return false if self.system?
    self[:user] == self.service.user if self.service
  end

  # この投稿が自分宛ならばtrueを返す
  def to_me?
    return true if self.system?
    if self.service
      return true if self.receiver == self.service.user
      return true if self[:message].to_s.include?(self.service.user)
    end
    false
  end

  # この投稿の投稿主を返す
  def user
    self.get(:user, -1) end

  # この投稿のServiceオブジェクトを返す
  def service
    if self[:post] then
      self[:post]
    elsif self.receive_message then
      self[:post] = self.receive_message.service end end

  # この投稿を宛てられたユーザを返す
  def receiver
    if self[:receiver].is_a? User
      self[:receiver]
    elsif self[:receiver]
      self[:receiver] = User.findbyid(self[:receiver])
    else
      match = (/@([a-zA-Z0-9_]+)/).match(self[:message].to_s)
      if match
        result = User.findbyidname(match[1])
        self[:receiver] = result if result end end end
  memoize :receiver

  # この投稿が別の投稿に宛てられたものならそれを返す。
  # _force_retrieve_ がtrueなら、呼び出し元のスレッドでサーバに問い合わせるので、
  # 親投稿を受信していなくてもこの時受信できるが、スレッドがブロッキングされる。
  # falseならサーバに問い合わせずに結果を返す。
  def receive_message(force_retrieve=false)
    count = if(force_retrieve) then -1 else 1 end
    reply = get(:replyto, count) or get(:retweet, count)
    if reply.is_a?(Message) and not reply.children.include?(self)
      reply.add_child(self) end
    reply end

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

  # この投稿に宛てられた投稿をSetオブジェクトにまとめて返す。
  def children
    @children ||= Plugin.filtering(:replied_by, self, Set.new())[1] + retweeted_statuses end

  # この投稿をお気に入りに登録したUserをSetオブジェクトにまとめて返す。
  def favorited_by
    @favorited ||= Plugin.filtering(:favorited_by, self, Set.new())[1] end

  # この投稿をリツイートしたユーザを返す
  def retweeted_by
    retweeted_statuses.map{ |x| x.user }.uniq
  end

  # この投稿に対するリツイートを返す
  def retweeted_statuses
    @retweets ||= Plugin.filtering(:retweeted_by, self, Set.new)[1]
    abort if @retweets.any?{ |x| not x.is_a? Message }
    @retweets
  end

  # 本文を返す
  def body
    text = self[:message].to_s.freeze
    result = [text]
    begin
      if self[:tags].is_a?(Array)
        result << self[:tags].select{|i| not text.include?(i) }.map{|i| "##{i.to_s}"} end
      if not receiver.nil?
        if self[:retweet] and self.receive_message(true)
          result << 'RT' << "@#{receiver[:idname]}" << self.receive_message(true)[:message]
        elsif not(text.include?("@#{receiver[:idname]}"))
          result = ["@#{receiver[:idname]}", result] end end
    rescue Exception => e
      error e
      abort end
    result.join(' ').freeze end
  memoize :body

  # 本文を返す。投稿制限文字数を超えていた場合には、収まるように末尾を捨てる。
  def to_s
    body.split(//u)[0,140].join.freeze end
  memoize :to_s

  # selfを返す
  def to_message
    self end

  # 本文を人間に読みやすい文字列に変換する
  def to_show
    body.gsub(/&(gt|lt|quot);/){|m| {'gt' => '>', 'lt' => '<', 'quot' => '"'}[$1] }.freeze end
  memoize :to_show

  # :nodoc:
  def marshal_dump
    raise RuntimeError, 'Message cannot marshalize'
  end

  # :nodoc:
  def add_favorited_by(user, time=Time.now)
    set_modified(time)
    favorited_by.add(user)
    Plugin.call(:favorite, service, user, self) end

  # :nodoc:
  def remove_favorited_by(user)
    favorited_by.delete(user)
    Plugin.call(:unfavorite, service, user, self) end

  # :nodoc:
  def add_child(child)
    type_strict child => Message
    Thread.new{
      if child[:retweet]
        retweeted_by unless defined? @retweets
        @retweets << child
        set_modified(child[:created])
      else
        children unless defined? @children
        @children << child
      end } end

  # 最終更新日時を取得する
  def modified
    self[:modified] ||= [self[:created], *(@retweets or []).map{ |x| x.modified }].select(&ret_nth).max end

  private

  def set_modified(time)
    if modified < time
      self[:modified] = time
      Plugin::call(:message_modified, self)
    end
    p [modified, time]
    self
  end

  def system
    { :id => @@system_id += 1,
      :user => User.system,
      :created => Time.now }
  end

  #
  # Sub classes
  #

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
end
