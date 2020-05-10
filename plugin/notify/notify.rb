# -*- coding: utf-8 -*-

Plugin.create(:notify) do

  DEFAULT_SOUND_DIRECTORY = File.join(Skin.default_dir, 'sounds')

  settings(_("通知")) do
    def self.defnotify(label, kind)
      settings (label) do
        boolean _('ポップアップ'), "notify_#{kind}".to_sym
        fileselect(_('サウンド'), "notify_sound_#{kind}".to_sym,
                   dir: DEFAULT_SOUND_DIRECTORY,
                   shortcuts: [DEFAULT_SOUND_DIRECTORY],
                   filters: {_('非圧縮音声ファイル (*.wav, *.aiff)') => ['wav', 'WAV', 'aiff', 'AIFF'],
                             _('FLAC (*.flac, *.fla)') => ['flac', 'FLAC', 'fla', 'FLA'],
                             _('MPEG-1/2 Audio Layer-3 (*.mp3)') => ['mp3', 'MP3'],
                             _('Ogg (*.ogg)') => ['ogg', 'OGG'],
                             _('全てのファイル') => ['*']
                            }) end end

    defnotify _("フレンドタイムライン"), :friend_timeline
    defnotify _("リプライ"), :mention
    defnotify _('フォローされたとき'), :followed
    defnotify _('フォロー解除されたとき'), :removed
    defnotify _('リツイートされたとき'), :retweeted
    defnotify _('ふぁぼられたとき'), :favorited
    defnotify _('ダイレクトメッセージ受信'), :direct_message
    adjustment(_('通知を表示し続ける秒数'), :notify_expire_time, 1, 60)
  end

  onupdate do |post, raw_messages|
    messages = Plugin.filtering(:show_filter, raw_messages.select{ |m| not(m.from_me? or m.to_me?) and m[:created] > defined_time }).first
    if not(messages.empty?)
      if(UserConfig[:notify_friend_timeline])
        messages.each{ |message|
          self.notify(message[:user], message) if not message.from_me? } end
      if(UserConfig[:notify_sound_friend_timeline])
        self.notify_sound(UserConfig[:notify_sound_friend_timeline]) end end end

  onmention do |post, raw_messages|
    messages = Plugin.filtering(:show_filter, raw_messages.select{ |m| not(m.from_me? or m[:retweet]) and m[:created] > defined_time }).first
    if not(messages.empty?)
      if(not(UserConfig[:notify_friend_timeline]) and UserConfig[:notify_mention])
        messages.each{ |message|
          self.notify(message[:user], message) } end
      if(UserConfig[:notify_sound_mention])
        self.notify_sound(UserConfig[:notify_sound_mention]) end end end

  on_followers_created do |post, users|
    if not(users.empty?)
      if(UserConfig[:notify_followed])
        self.notify(users.first, _('%{users} にフォローされました。') % {users: users.map{|u| u && "@#{u[:idname]}" }.join(' ')}) end
      if(UserConfig[:notify_sound_followed])
        self.notify_sound(UserConfig[:notify_sound_followed]) end end end

  on_followers_destroy do |post, users|
    if not(users.empty?)
      if(UserConfig[:notify_removed])
        self.notify(users.first, _('%{users} にリムーブされました。') % {users: users.map{|u| u && "@#{u[:idname]}" }.join(' ')}) end
      if(UserConfig[:notify_sound_removed])
        self.notify_sound(UserConfig[:notify_sound_removed]) end end end

  on_favorite do |service, by, to|
    if to.from_me?
      if(UserConfig[:notify_favorited])
        self.notify(by, _("fav by %{from_user} \"%{tweet}\"") % {
                      from_user: by[:idname],
                      tweet: to.to_s }) end
      if(UserConfig[:notify_sound_favorited])
        self.notify_sound(UserConfig[:notify_sound_favorited]) end end end

  onmention do |_, raw_messages|
    messages = Plugin.filtering(:show_filter, raw_messages.select{ |m| m.created > defined_time && m.retweet? && !m.from_me? }).first.to_a
    if !messages.empty?
      if UserConfig[:notify_retweeted]
        messages.each do |message|
          self.notify(message[:user], _('Share: %{tweet}') % {tweet: message.to_s})
        end
      end
      if(UserConfig[:notify_sound_retweeted])
        self.notify_sound(UserConfig[:notify_sound_retweeted])
      end
    end
  end

  on_direct_messages do |post, dms|
    newer_dms = dms.select{ |dm| Time.parse(dm[:created_at]) > defined_time }
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
