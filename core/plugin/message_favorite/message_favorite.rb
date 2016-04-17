# -*- coding: utf-8 -*-
Plugin.create :message_favorite do
  message_fragment :favorited, "Favorite" do
    set_icon Skin.get('unfav.png')
    user_list = Gtk::UserList.new
    begin
      user_list.add_user Users.new(retriever.favorited_by.to_a)
    rescue => err
      error err
    end
    nativewidget user_list
  end
end
