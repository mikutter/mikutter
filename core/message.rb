#
# message.rb
#

miquire :core, 'autotag'
miquire :core, 'user'
miquire :core, 'image'

class Message
  @@autotag = AutoTag.new
  @@cache = Hash.new

  # args format
  # key     | value(class)
  #---------+--------------
  # id      | id of status(mixed)
  # message | posted text(String)
  # tags    | kind of message(Array)
  # user    | user who post this message(User or Hash or mixed(User IDNumber))
  # reciver | recive user(User)
  # replyto | source message(Message or mixed(Status ID))
  # post    | post object(Post)
  # image   | image(URL or Image object)
  # xml     | source xml text
  def initialize(message, *args)
    if(args.size == 1 and args[0].is_a?(Hash)) then
      @value = args[0]
      @value[:message] = message
    elsif(args.size == 0 and message.is_a?(Hash)) then
      @value = message
    else
      @value = Hash.new
      @value[:tags], @value[:replyto] = args
      @value[:message] = message
    end
    @value[:tags] = @@autotag.get(@value[:message]) unless @value[:tags]
    @value[:user] = User.generate(@value[:user]) if @value[:user]
    if not(@value[:image].is_a?(Message::Image)) then
      @value[:image] = Message::Image.new(@value[:image])
    end
    self.regist
  end

  def self.generate(message, args)
    if(@@messages[args[:id]]) then
      @@messages[args[:id]].merge(args)
    else
      @@messages[args[:id]] = Message.new(message, args)
    end
  end

  # このつぶやきへのリプライをつぶやく
  def post(other, &proc)
    if not(other.receive_message) then
      other[:replyto] = self
    end
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
      self[:favorited]
    end
  end

  def update(other)
    @value.update(other){|*a| a[1] }
    return self
  end

  def <<(msg)
    if (msg.instance_of Symbol)
      self[:tags] << msg
    else
      self[:message] << msg
    end
  end

  def from_me?
    self[:user] == self[:post].user
  end

  def to_me?
    self.receiver == self[:post].user
  end

  # return receive user
  def receiver
    if self[:receiver] then
      self[:receiver]
    elsif self.receive_message.is_a?(Message) then
      self.receive_message[:user]
    elsif(/@([a-zA-Z0-9_]+)/ === self[:message]) then
      result = User.findByIdname($1)
      if(result) then
        self[:receiver] = result
      end
      result
    end
  end

  def receive_message(force_retrieve=false)
    result = (self[:replyto] or self[:retweet])
    if(result) and not(result.is_a?(Message)) then
      cache = at(result)
      if(cache) then
        result = cache
      elsif(force_retrieve)
        retrieve = self[:post].scan(:status_show, :id => result, :no_auto_since_id => true)
        if(retrieve)
           result = self[:replyto] = retrieve.first
        end
      end
    end
    return result
  end

  def [](key)
    @value[key.to_sym]
  end

  def []=(key, val)
    @value[key.to_sym] = val
  end

  def at(key)
    return @@cache[key.to_i]
  end

  def regist
    if(self[:id]) then
      @@cache[self[:id].to_i] = self
    end
  end

  def to_s
    result = [self[:message], self[:tags].select{|i| not self[:message].include?(i) }.map{|i| "##{i.to_s}"}]
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

  def inspect
    "Message[#{if self.favorite? then '*' end}#{@value[:user].inspect}: #{@value[:message]}] to #{(self.receive_message or self.receiver).inspect}"
  end
end
