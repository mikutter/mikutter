#
# message.rb
#

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
               [:created, :time],         # posted time
              ]

  def initialize(value)
    assert_type(Hash, value)
    value.update(self.system) if value[:system]
    if not(value[:image].is_a?(Message::Image)) then
      value[:image] = Message::Image.new(value[:image])
    end
    super(value)
  end

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
    if self[:post] then
      self[:post].post(other){|*a| yield *a }
    elsif self.receive_message then
      self.receive_message.post(other){|*a| yield *a }
    end
  end

  # ふぁぼる／ふぁぼ解除
  def favorite(fav)
    self[:post].favorite(self, fav)
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
    self[:post] != nil
  end

  def from_me?
    return false if self.system?
    self[:user] == self[:post].user if self[:post]
  end

  def to_me?
    return true if self.system?
    if self[:post]
      return true if self.receiver == self[:post].user
      return true if self[:message].include?(self[:post].user)
    end
    false
  end

  # return receive user
  def receiver
    if self[:receiver] then
      self[:receiver]
    #elsif self.receive_message.is_a?(Message) then
    #  self.receive_message[:user]
    elsif(/@([a-zA-Z0-9_]+)/ === self[:message]) then
      result = User.findByIdname($1)
      if(result) then
        self[:receiver] = result
      end
      result
    end
  end

  def receive_message(force_retrieve=false)
    count = if(force_retrieve) then -1 else 0 end
    self.get(:replyto, count)
  end

  def to_s
    result = [self[:message]]
    if self[:tags].is_a?(Array)
      result << self[:tags].select{|i| not self[:message].include?(i) }.map{|i| "##{i.to_s}"}
    end
    if self.receiver then
      if self[:retweet] then
        result << 'RT' << "@#{self.receiver[:idname]}" << self.receive_message[:message]
      else
        if not(self[:message].include?("@#{self.receiver[:idname]}")) then
          result = ["@#{self.receiver[:idname]}", result]
        end
      end
    end
    return result.join(' ').split(//u)[0,140].join
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
