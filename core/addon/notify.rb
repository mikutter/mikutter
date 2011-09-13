# -*- coding: utf-8 -*-
miquire :addon, 'addon'
miquire :core, 'environment'
miquire :addon, 'settings'

#require 'gst'

Module.new do

  DEFAULT_SOUND_DIRECTORY = 'skin/data/sounds'
  DEFINED_TIME = Time.new.freeze

  def self.boot
    plugin = Plugin::create(:notify)

    plugin.add_event(:boot){ |service|
      Plugin.call(:setting_tab_regist, main, '通知') }
    plugin.add_event(:update, &method(:onupdate))
    plugin.add_event(:mention, &method(:onmention))
    plugin.add_event(:mention, &method(:onretweeted))
    plugin.add_event(:followers_created, &method(:onfollowed))
    plugin.add_event(:followers_destroy, &method(:onremoved))
    plugin.add_event(:favorite, &method(:onfavorited))
  end

  def self.main
    box = Gtk::VBox.new(false, 8)
    ft = Mtk.group('フレンドタイムライン',
                   Mtk.boolean(:notify_friend_timeline, 'ポップアップ'),
                   Mtk.fileselect(:notify_sound_friend_timeline, 'サウンド', DEFAULT_SOUND_DIRECTORY))
    me = Mtk.group('リプライ',
                   Mtk.boolean(:notify_mention, 'ポップアップ'),
                   Mtk.fileselect(:notify_sound_mention, 'サウンド', DEFAULT_SOUND_DIRECTORY))
    fd = Mtk.group('フォローされたとき',
                   Mtk.boolean(:notify_followed, 'ポップアップ'),
                   Mtk.fileselect(:notify_sound_followed, 'サウンド', DEFAULT_SOUND_DIRECTORY))
    rd = Mtk.group('フォロー解除されたとき',
                   Mtk.boolean(:notify_removed, 'ポップアップ'),
                   Mtk.fileselect(:notify_sound_removed, 'サウンド', DEFAULT_SOUND_DIRECTORY))
    rt = Mtk.group('リツイートされたとき',
                   Mtk.boolean(:notify_retweeted, 'ポップアップ'),
                   Mtk.fileselect(:notify_sound_retweeted, 'サウンド', DEFAULT_SOUND_DIRECTORY))
    fv = Mtk.group('ふぁぼられたとき',
                   Mtk.boolean(:notify_favorited, 'ポップアップ'),
                   Mtk.fileselect(:notify_sound_favorited, 'サウンド', DEFAULT_SOUND_DIRECTORY))
    box.closeup(ft).closeup(me).closeup(fd).closeup(rd).closeup(rt).closeup(fv)
    box.pack_start(Mtk.adjustment('通知を表示し続ける秒数', :notify_expire_time, 1, 60), false)
  end

  def self.onupdate(post, raw_messages)
    messages = Plugin.filtering(:show_filter, raw_messages.select{ |m| not(m.from_me? or m.to_me?) and m[:created] > DEFINED_TIME }).first
    if not(messages.empty?)
      if(UserConfig[:notify_friend_timeline])
        messages.each{ |message|
          self.notify(message[:user], message) if not message.from_me? } end
      if(UserConfig[:notify_sound_friend_timeline])
        self.notify_sound(UserConfig[:notify_sound_friend_timeline]) end end end

  def self.onmention(post, raw_messages)
    messages = Plugin.filtering(:show_filter, raw_messages.select{ |m| not(m.from_me? or m[:retweet]) and m[:created] > DEFINED_TIME }).first
    if not(messages.empty?)
      if(not(UserConfig[:notify_friend_timeline]) and UserConfig[:notify_mention])
        messages.each{ |message|
          self.notify(message[:user], message) } end
      if(UserConfig[:notify_sound_mention])
        self.notify_sound(UserConfig[:notify_sound_mention]) end end end

  def self.onfollowed(post, users)
    if not(users.empty?)
      if(UserConfig[:notify_followed])
        users.each{ |user|
          self.notify(users.first, users.map{|u| "@#{u[:idname]}" }.join(' ')+' にフォローされました。') } end
      if(UserConfig[:notify_sound_followed])
        self.notify_sound(UserConfig[:notify_sound_followed]) end end end

  def self.onremoved(post, users)
    if not(users.empty?)
      if(UserConfig[:notify_removed])
        self.notify(users.first, users.map{|u| "@#{u[:idname]}" }.join(' ')+' にリムーブされました。') end
      if(UserConfig[:notify_sound_removed])
        self.notify_sound(UserConfig[:notify_sound_removed]) end end end

  def self.onfavorited(service, by, to)
    if to.from_me?
      if(UserConfig[:notify_favorited])
        self.notify(by, "fav by #{by[:idname]} \"#{to.to_s}\"") end
      if(UserConfig[:notify_sound_favorited])
        self.notify_sound(UserConfig[:notify_sound_favorited]) end end end

  def self.onretweeted(post, raw_messages)
    messages = Plugin.filtering(:show_filter, raw_messages.select{ |m| m[:retweet] and not m.from_me? }).first
    if not(messages.empty?)
      if(UserConfig[:notify_retweeted])
        messages.each{ |message|
          self.notify(message[:user], 'ReTweet: ' +  message.to_s) } end
      if(UserConfig[:notify_sound_retweeted])
        self.notify_sound(UserConfig[:notify_sound_retweeted]) end end end

  def self.notify(user, text)
    Plugin.call(:popup_notify, user, text) end

  def self.notify_sound(sndfile)
    if sndfile.respond_to?(:to_s) and FileTest.exist?(sndfile.to_s)
      Plugin.call(:play_sound, sndfile) end end

  boot
end
