# -*- coding: utf-8 -*-
# notify-sendコマンドで通知を表示する

Module.new do

  if command_exist? 'notify-send'
    Plugin::create(:libnotify).add_event(:popup_notify){ |user, text, &stop|
      command = ["notify-send"]
      if(text.is_a? Message)
        command << '--category=system'
        text = text.to_s
      end
      command << '-t' << UserConfig[:notify_expire_time].to_s + '000'
      if user
        command << "-i" << Gtk::WebIcon.local_path(user[:profile_image_url])
        command << "@#{user[:idname]} (#{user[:name]})" end
      command << text
      bg_system(*command)
      stop.call
    }
  end

end
