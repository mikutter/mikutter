miquire :addon, 'addon'
miquire :core, 'config'
miquire :addon, 'settings'
miquire :lib, 'escape'

#require 'gst'

module Addon
  class Notify < Addon

    include SettingUtils

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
                     gen_fileselect(:notify_sound_friend_timeline, 'サウンド', 'core/skin/data/sounds'))
      me = gen_group('リプライ',
                     gen_boolean(:notify_mention, 'ポップアップ'),
                     gen_fileselect(:notify_sound_mention, 'サウンド', 'core/skin/data/sounds'))
      fd = gen_group('フォローされたとき',
                     gen_boolean(:notify_followed, 'ポップアップ'),
                     gen_fileselect(:notify_sound_followed, 'サウンド', 'core/skin/data/sounds/'))
      box.pack_start(ft, false).pack_start(me, false).pack_start(fd, false)
      box.pack_start(gen_adjustment('通知を表示し続ける秒数', :notify_expire_time, 1, 60), false)
      return box
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
        system(*command)
      }
    end

    def notify_sound(sndfile)
      # hack! linux only
      system('sh', '-c', "aplay -q #{Escape.shell_command(sndfile).to_s} &")
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
end

Plugin::Ring.push Addon::Notify.new,[:boot, :update, :mention, :followed]
