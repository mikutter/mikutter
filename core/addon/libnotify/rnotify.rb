# -*- coding: utf-8 -*-
# ruby-libnotifyを使用して通知

Plugin::create(:libnotify) do
  on_popup_notify do |user, text, &stop|

    icon = nil
    title = nil
    category = nil
    timeout = UserConfig[:notify_expire_time].to_i * 1000

    if text.is_a? Message
      text = text.to_s
    end

    if user
      icon = Gtk::WebImageLoader.local_path(user[:profile_image_url])
      title = "@#{user[:idname]} (#{user[:name]})"
    end

    n = Notify::Notification.new(*[title, text, icon, nil][0, [3, Notify::Notification.method(:new).arity].max])
    n.timeout = timeout
    n.category = category
    n.show
    Reserver.new(timeout) { n.close }
    stop.call
  end

  END { Notify.uninit }
end
