
Module.new do

  @last_forenotify = Hash.new{ Hash.new(1000) }

  # 毎分のイベントハンドラ

  plugin = Plugin::create(:kiriban)
  plugin.add_event(:update){ |service, messages|
    messages.each{ |message| onupdate(service, message) } }

  plugin.add_event(:mention){ |service, messages|
    messages.each{ |message|
      message.user.follow if /フォローして/ === message.to_s } }

  def self.onupdate(watch, message)
    if(!message[:user] or message[:user][:idname] == watch.user) then
      notice "kiriban: reject message user #{message[:user].inspect}"
      return nil
    end
    number = message[:statuses_count]
    if(number) then
      number = number.to_i
      seed = (rand(10) + 1) * 10**rand(2)
      if(self.kiriban?(number)) then
        @last_forenotify[message[:user][:idname]][number] = 0
        return watch.post(:message => "#{number}回目のツイートです！おめでとう！",
                          :tags => [self.name],
                          :retweet => message)
      elsif(self.kiriban?(number + seed)) then
        if(@last_forenotify[message[:user][:idname]][number] > seed) then
          @last_forenotify[message[:user][:idname]][number] = seed
          return watch.post(:message => "あと#{seed}回で#{number + seed}ツイート達成です！もうちょっと！",
                            :tags => [self.name],
                            :replyto => message)
        end
      end
      notice "kiriban: tweet count #{number} #{message.inspect}"
    end
  end

  def self.kiriban?(num)
    if(num >= 100) then
      multiple_number?(num) or zerofill_number?(num)
    end
  end

  def self.multiple_number?(num)
    (num.to_s =~ /^(\d)\1+$/) == 0
  end

  def self.zerofill_number?(num)
    (num.to_s =~ /^\d0+$/) == 0
  end

end

