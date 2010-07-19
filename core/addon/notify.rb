miquire :addon, 'addon'
miquire :core, 'config'
miquire :addon, 'settings'

#require 'gst'

Module.new do

  DEFAULT_SOUND_DIRECTORY = 'skin/data/sounds'

  def self.boot
    plugin = Plugin::create(:notify)

    plugin.add_event(:boot){ |service|
      Plugin.call(:setting_tab_regist, main, '通知') }
    plugin.add_event(:update, &method(:onupdate))
    plugin.add_event(:mention, &method(:onmention))
    plugin.add_event(:followers_created, &method(:onfollowed))
    plugin.add_event(:followers_destroy, &method(:onremoved))
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
    box.closeup(ft).closeup(me).closeup(fd).closeup(rd)
    box.pack_start(Mtk.adjustment('通知を表示し続ける秒数', :notify_expire_time, 1, 60), false)
  end

  def self.onupdate(post, raw_messages)
    messages = raw_messages.select{ |m| not(m.from_me? or m.to_me?) }
    if not(first?(:update) or messages.empty?) then
      if(UserConfig[:notify_friend_timeline]) then
        messages.each{ |message|
          self.notify(message[:user], message) if not message.from_me?
        }
      end
      if(UserConfig[:notify_sound_friend_timeline]) then
        self.notify_sound(UserConfig[:notify_sound_friend_timeline])
      end
    end
  end

  def self.onmention(post, raw_messages)
    messages = raw_messages.select{ |m| not m.from_me? }
    if not(first?(:mention) or messages.empty?) then
      if(not(UserConfig[:notify_friend_timeline]) and UserConfig[:notify_mention]) then
        messages.each{ |message|
          self.notify(message[:user], message)
        }
      end
      if(UserConfig[:notify_sound_mention]) then
        self.notify_sound(UserConfig[:notify_sound_mention])
      end
    end
  end

  def self.onfollowed(post, users)
    if not(users.empty?) then
      if(UserConfig[:notify_followed]) then
        users.each{ |user|
          self.notify(user, 'にフォローされました。')
        }
      end
      if(UserConfig[:notify_sound_followed]) then
        self.notify_sound(UserConfig[:notify_sound_followed])
      end
    end
  end

  def self.onremoved(post, users)
    if not(users.empty?) then
      if(UserConfig[:notify_removed]) then
        users.each{ |user|
          self.notify(user, 'にリムーブされました。')
        }
      end
      if(UserConfig[:notify_sound_removed]) then
        self.notify_sound(UserConfig[:notify_sound_removedd])
      end
    end
  end

  def self.first?(func)
    @called = [] if not defined? @called
    if @called.include?(func) then
      false
    else
      @called << func
      true
    end
  end

  def self.notify(user, text)
    Thread.new(user, text){ |user, text|
      command = ["notify-send"]
      if(text.is_a? Message) then
        command << '--category=system'
        text = text.to_s
      end
      command << '-t' << UserConfig[:notify_expire_time].to_s + '000'
      command << "-i" << Gtk::WebIcon.local_path(user[:profile_image_url])
      command << "@#{user[:idname]} (#{user[:name]})" <<  text
      bg_system(*command) } end

  def self.notify_sound(sndfile)
    # hack! linux only
    bg_system("aplay","-q", sndfile) if FileTest.exist?(sndfile) end

  boot
end

#Plugin::Ring.push Addon::Notify.new,[:boot, :update, :mention, :followed]
