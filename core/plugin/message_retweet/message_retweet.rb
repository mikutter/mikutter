# -*- coding: utf-8 -*-
Plugin.create :message_retweet do
  message_fragment :retweeted, "ReTweet" do
    user_list = Gtk::UserList.new
    begin
      user_list.add_user Users.new(retriever.retweeted_by.to_a)
    rescue => err
    error err
    end
    nativewidget user_list
  end
end
