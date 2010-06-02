miquire :addon, 'addon'
miquire :core, 'config'
miquire :addon, 'settings'

#require 'gst'

class Addon::Notify < Addon::Addon

  include Addon::SettingUtils

  DEFAULT_SOUND_DIRECTORY = 'skin/data/sounds'

  @@mutex = Monitor.new

  get_all_parameter_once :update, :mention, :followed

  def onboot(watch)
    container = self.main(watch)
    Plugin::Ring::fire(:plugincall, [:settings, watch, :regist_tab, container, '通知'])
  end

  def main(watch)
    box = Gtk::VBox.new(false, 8)
    ft = gen_group('フレンドタイムライン',
                   gen_boolean(:notify_friend_timeline, 'ポップアップ'),
                   gen_fileselect(:notify_sound_friend_timeline, 'サウンド', DEFAULT_SOUND_DIRECTORY))
    me = gen_group('リプライ',
                   gen_boolean(:notify_mention, 'ポップアップ'),
                   gen_fileselect(:notify_sound_mention, 'サウンド', DEFAULT_SOUND_DIRECTORY))
    fd = gen_group('フォローされたとき',
                   gen_boolean(:notify_followed, 'ポップアップ'),
                   gen_fileselect(:notify_sound_followed, 'サウンド', DEFAULT_SOUND_DIRECTORY))
    box.pack_start(ft, false).pack_start(me, false).pack_start(fd, false)
    box.pack_start(gen_adjustment('通知を表示し続ける秒数', :notify_expire_time, 1, 60), false)
  end

  def onupdate(alist)
    if(not first?(:update)) then
      if(UserConfig[:notify_friend_timeline]) then
        alist.each{ |post, message|
          self.notify(message[:user], message) if not message.from_me?
        }
      end
      if(UserConfig[:notify_sound_friend_timeline]) then
        self.notify_sound(UserConfig[:notify_sound_friend_timeline])
      end
    end
  end

  def onmention(alist)
    if(not first?(:mention)) then
      if(not(UserConfig[:notify_friend_timeline]) and UserConfig[:notify_mention]) then
        alist.each{ |post, message|
          self.notify(message[:user], message) if not message.from_me?
        }
      end
      if(UserConfig[:notify_sound_mention]) then
        self.notify_sound(UserConfig[:notify_sound_mention])
      end
    end
  end

  def onfollowed(alist)
    if(not first?(:followed)) then
      if(UserConfig[:notify_follower]) then
        alist.each{ |post, user|
          self.notify(user, 'にフォローされました。')
        }
      end
      if(UserConfig[:notify_sound_followed]) then
        self.notify_sound(UserConfig[:notify_sound_followed])
      end
    end
  end

  def first?(func)
    @called = [] if not defined? @called
    if @called.include?(func) then
      false
    else
      @called << func
      true
    end
  end

  def notify(user, text)
    Thread.new(user, text){ |user, text|
      command = ["notify-send"]
      if(text.is_a? Message) then
        command << '--category=system'
        text = text.to_s
      end
      command << '-t' << UserConfig[:notify_expire_time].to_s + '000'
      command << "-i" << Gtk::WebIcon.local_path(user[:profile_image_url])
      command << "@#{user[:idname]} (#{user[:name]})" <<  text
      bg_system(*command)
    }
  end

  def notify_sound(sndfile)
    # hack! linux only
    bg_system("aplay","-q", sndfile) if FileTest.exist?(sndfile)
    return
    # if ubuntu karmic, always segmentation fault.
    uri = 'file://'+ File.join(File.expand_path(sndfile))
    if not defined? @sound then
      @sound = Hash.new{ |hash,key|
        result = Gst::ElementFactory.make("playbin")
        result.ready
        result.uri = uri
        hash[key] = result
      }
    end
    @sound[uri].seek(Gst::EventSeek::FLUSH_START, 0)
    @sound[uri].play
  end

end

Plugin::Ring.push Addon::Notify.new,[:boot, :update, :mention, :followed]
