# -*- coding: utf-8 -*-
# notify-sendコマンドで通知

Plugin::create(:libnotify) do
  on_popup_notify do |user, text, &stop|
    icon_path(user.icon).trap{|err|
      warn err
      icon_path(Skin[:notfound])
    }.next{|icon_file_name|
      command = ['notify-send']
      if text.is_a? Diva::Model
        command << '--category=system'
        text = text.description
      end
      command << '-t' << '%d000' % UserConfig[:notify_expire_time]
      command << "-i" << icon_file_name << user.title
      command << "-a" << Environment::NAME
      command << text.to_s
      bg_system(*command)
    }.trap{|err|
      error err
      notice "user=#{user.inspect}, text=#{text.inspect}"
    }
    stop.call
  end

  def icon_path(photo)
    fn = File.join(icon_tmp_dir, Digest::MD5.hexdigest(photo.uri.to_s) + '.png')
    Delayer::Deferred.new.next{
      case
      when FileTest.exist?(fn)
        fn
      else
        photo.download_pixbuf(width: 48, height: 48).next{|p|
          FileUtils.mkdir_p(icon_tmp_dir)
          photo.pixbuf(width: 48, height: 48).save(fn, 'png')
          fn
        }
      end
    }
  end

  memoize def icon_tmp_dir
    File.join(Environment::TMPDIR, 'libnotify', 'icon').freeze
  end
end if command_exist? 'notify-send' # notify-sendコマンドが有る場合
