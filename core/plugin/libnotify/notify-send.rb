# -*- coding: utf-8 -*-
# notify-sendコマンドで通知

Plugin::create(:libnotify) do
  on_popup_notify do |user, text, &stop|
    icon_path(user.icon).trap{|err|
      warn err
      icon_path(Skin['notfound.png'])
    }.next{|icon_file_name|
      command = ["notify-send"]
      if(text.is_a? Message)
        command << '--category=system'
        text = text.to_s
      end
      command << '-t' << UserConfig[:notify_expire_time].to_s + '000'
      if user
        command << "-i" << icon_file_name
        command << user.title end
      command << text
      bg_system(*command)
    }.terminate
    stop.call
  end

  def icon_path(photo)
    ext = photo.uri.path.split('.').last || 'png'
    fn = File.join(icon_tmp_dir, Digest::MD5.hexdigest(photo.uri.to_s) + ".#{ext}")
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
end
