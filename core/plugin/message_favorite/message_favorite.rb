# -*- coding: utf-8 -*-
Plugin.create :message_favorite do
  message_fragment :favorited, "Favorite" do
    message = model
    set_icon Skin[:unfav]
    user_list = Gtk::UserList.new
    begin
      user_list.add_user model.favorited_by
    rescue => err
      error err
    end
    nativewidget user_list

    on_favorite do |service, user, to_message|
      if to_message == message
        user_list.add_user([user]) end end

  end
end
