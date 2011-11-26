# -*- coding: utf-8 -*-

Plugin.create(:notify) do

  DEFAULT_SOUND_DIRECTORY = 'skin/data/sounds'
  DEFINED_TIME = Time.new.freeze

  settings("通知") do
    def self.defnotify(label, kind)
      settings (label) do
        boolean 'ポップアップ', "notify_#{kind}".to_sym
      fileselect('サウンド', "notify_sound_#{kind}".to_sym, DEFAULT_SOUND_DIRECTORY) end end

    defnotify "フレンドタイムライン", :friend_timeline
    defnotify "リプライ", :mention
    defnotify 'フォローされたとき', :followed
    defnotify 'フォロー解除されたとき', :removed
    defnotify 'リツイートされたとき', :retweeted
    defnotify 'ふぁぼられたとき', :favorited
    defnotify 'ダイレクトメッセージ受信', :direct_message
    adjustment('通知を表示し続ける秒数', :notify_expire_time, 1, 60)
  end

  onupdate do |post, raw_messages|
    messages = Plugin.filtering(:show_filter, raw_messages.select{ |m| not(m.from_me? or m.to_me?) and m[:created] > DEFINED_TIME }).first
    if not(messages.empty?)
      if(UserConfig[:notify_friend_timeline])
        messages.each{ |message|
          self.notify(message[:user], message) if not message.from_me? } end
      if(UserConfig[:notify_sound_friend_timeline])
        self.notify_sound(UserConfig[:notify_sound_friend_timeline]) end end end

  onmention do |post, raw_messages|
    messages = Plugin.filtering(:show_filter, raw_messages.select{ |m| not(m.from_me? or m[:retweet]) and m[:created] > DEFINED_TIME }).first
    if not(messages.empty?)
      if(not(UserConfig[:notify_friend_timeline]) and UserConfig[:notify_mention])
        messages.each{ |message|
          self.notify(message[:user], message) } end
      if(UserConfig[:notify_sound_mention])
        self.notify_sound(UserConfig[:notify_sound_mention]) end end end

  on_followers_created do |post, users|
    if not(users.empty?)
      if(UserConfig[:notify_followed])
        users.each{ |user|
          self.notify(users.first, users.map{|u| "@#{u[:idname]}" }.join(' ')+' にフォローされました。') } end
      if(UserConfig[:notify_sound_followed])
        self.notify_sound(UserConfig[:notify_sound_followed]) end end end

  on_followers_destroy do |post, users|
    if not(users.empty?)
      if(UserConfig[:notify_removed])
        self.notify(users.first, users.map{|u| "@#{u[:idname]}" }.join(' ')+' にリムーブされました。') end
      if(UserConfig[:notify_sound_removed])
        self.notify_sound(UserConfig[:notify_sound_removed]) end end end

  on_favorite do |service, by, to|
    if to.from_me?
      if(UserConfig[:notify_favorited])
        self.notify(by, "fav by #{by[:idname]} \"#{to.to_s}\"") end
      if(UserConfig[:notify_sound_favorited])
        self.notify_sound(UserConfig[:notify_sound_favorited]) end end end

  onmention do |post, raw_messages|
    messages = Plugin.filtering(:show_filter, raw_messages.select{ |m| m[:retweet] and not m.from_me? }).first
    if not(messages.empty?)
      if(UserConfig[:notify_retweeted])
        messages.each{ |message|
          self.notify(message[:user], 'ReTweet: ' +  message.to_s) } end
      if(UserConfig[:notify_sound_retweeted])
        self.notify_sound(UserConfig[:notify_sound_retweeted]) end end end

  on_direct_messages do |post, dms|
    newer_dms = dms.select{ |dm| Time.parse(dm[:created_at]) > DEFINED_TIME }
    if not(newer_dms.empty?)
      if(UserConfig[:notify_direct_message])
        newer_dms.each{ |dm|
          self.notify(User.generate(dm[:sender]), dm[:text]) } end
      if(UserConfig[:notify_sound_direct_message])
        self.notify_sound(UserConfig[:notify_sound_direct_message]) end end end

  def self.notify(user, text)
    Plugin.call(:popup_notify, user, text) end

  def self.notify_sound(sndfile)
    if sndfile.respond_to?(:to_s) and FileTest.exist?(sndfile.to_s)
      Plugin.call(:play_sound, sndfile) end end

end
