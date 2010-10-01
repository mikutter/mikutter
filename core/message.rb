#
# message.rb
#

require File.expand_path('utils')
miquire :core, 'autotag'
miquire :core, 'user'
miquire :core, 'retriever'

require 'net/http'

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
             ]

  def initialize(value)
    assert_type(Hash, value)
    value.update(self.system) if value[:system]
    if not(value[:image].is_a?(Message::Image)) and value[:image]
      value[:image] = Message::Image.new(value[:image]) end
    super(value)
    if self[:replyto].is_a? Message
      self[:replyto].add_child(self) end
    if UserConfig[:shrinkurl_expand] and MessageConverters.shrinkable_url_regexp === value[:message]
      self[:message] = MessageConverters.expand_url_all(value[:message]) end end

  def system
    { :id => @@system_id += 1,
      :user => User.system,
      :created => Time.now }
  end

  def idname
    self[:user][:idname]
  end

  # このつぶやきへのリプライをつぶやく
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

  def destroy
    self.service.destroy(self){|*a| yield *a if block_given? } if self.service
  end

  # ふぁぼる／ふぁぼ解除
  def favorite(fav)
    self.service.favorite(self, fav)
  end

  def favorite?
    if self[:favorited].is_a?(String) then
      self[:favorited] = self[:favorited] == 'true'
    else
      self[:favorited] == true
    end
  end

  def favoriable?
    not system?
  end

  def <<(msg)
    if (msg.instance_of Symbol)
      self[:tags] << msg
    else
      self[:message] << msg
    end
  end

  def system?
    self[:system]
  end

  def repliable?
    self.service != nil
  end

  def from_me?
    return false if self.system?
    self[:user] == self.service.user if self.service
  end

  def to_me?
    return true if self.system?
    if self.service
      return true if self.receiver == self.service.user
      return true if self[:message].include?(self.service.user)
    end
    false
  end

  def user
    self.get(:user, -1) end

  def service
    if self[:post] then
      self[:post]
    elsif self.receive_message then
      self[:post] = self.receive_message.service end end

  # return receive user
  def receiver
    if self[:receiver].is_a? User
      self[:receiver]
    elsif self[:receiver]
      self[:receiver] = User.findbyid(self[:receiver])
    else
      match = (/@([a-zA-Z0-9_]+)/).match(self[:message])
      if match
        result = User.findbyidname(match[1])
        self[:receiver] = result if result
      end
    end
  end

  def receive_message(force_retrieve=false)
    count = if(force_retrieve) then -1 else 1 end
    reply = get(:replyto, count) or get(:retweet, count)
    if reply.is_a?(Message) and not reply.children.include?(self)
      reply.add_child(self) end
    reply end

  def each_ancestors(force_retrieve=false, &proc)
    proc.call(self)
    parent = receive_message(force_retrieve)
    parent.each_ancestors(force_retrieve, &proc) if parent
  end

  def ancestors(force_retrieve=false)
    parent = receive_message(force_retrieve)
    return [self, *parent.ancestors(force_retrieve)] if parent
    [self]
  end

  def ancestor(force_retrieve=false)
    ancestors(force_retrieve).last
  end

  def add_child(child)
    children << child end

  def children
    @children ||= Set.new(Message.selectby(:replyto, self[:id])) end

  def body
    result = [self[:message]]
    if self[:tags].is_a?(Array)
      result << self[:tags].select{|i| not self[:message].include?(i) }.map{|i| "##{i.to_s}"} end
    if self.receiver
      if self[:retweet] and self.receive_message(true)
        result << 'RT' << "@#{receiver[:idname]}" << self.receive_message(true)[:message]
      elsif not(self[:message].include?("@#{receiver[:idname]}"))
        result = ["@#{receiver[:idname]}", result] end end
    result.join(' ') end

  def to_s
    body.split(//u)[0,140].join
  end

  def to_show
    body.gsub(/&([gl])t;/){|m| {'g' => '>', 'l' => '<'}[$1] }
  end

  def marshal_dump
    raise RuntimeError, 'Message cannot marshalize'
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
