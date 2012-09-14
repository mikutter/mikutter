# -*- coding: utf-8 -*-
# notify-sendコマンドで通知

Plugin::create(:libnotify) do
  on_popup_notify do |user, text, &stop|
    SerialThread.new{
      command = ["notify-send"]
      if(text.is_a? Message)
        command << '--category=system'
        text = text.to_s
      end
      command << '-t' << UserConfig[:notify_expire_time].to_s + '000'
      if user
        command << "-i" << Gdk::WebImageLoader.local_path(user[:profile_image_url])
        command << "@#{user[:idname]} (#{user[:name]})" end
      command << text
      notice command
      begin
        bg_system(*command)
      rescue => e
        error e
      end }
    stop.call end end
