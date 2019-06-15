# -*- coding: utf-8 -*-
# libnotify gemで通知する

require 'libnotify'

Plugin.create :libnotify do
  on_popup_notify do |user, text, &stop|
    if text.is_a? Diva::Model
      text = text.description
    end
    notify = Libnotify.new(
      body: text,
      summary: user.title,
      timeout: UserConfig[:notify_expire_time].to_f
    )
    notify.update
    icon_path(user.icon).trap{|err|
      warn err
      icon_path(Skin['notfound.png'])
    }.next{|icon_file_name|
      notify.icon_path = icon_file_name
      notify.update
    }.trap{|err|
      error err
      notice "user=#{user.inspect}, text=#{text.inspect}"
    }
    stop.call
  end

  def icon_path(photo)
    fn = File.join(icon_tmp_dir, Digest::MD5.hexdigest(photo.uri.to_s) + '.png')
    Delayer::Deferred.new.next{
      if FileTest.exist?(fn)
        fn
      else
        photo.download_pixbuf(width: 48, height: 48).next{|p|
          if !FileTest.exist?(fn)
            FileUtils.mkdir_p(icon_tmp_dir)
            photo.pixbuf(width: 48, height: 48).save(fn, 'png')
          end
          fn
        }
      end
    }
  end

  memoize def icon_tmp_dir
    File.join(Environment::TMPDIR, 'libnotify', 'icon').freeze
  end
end
