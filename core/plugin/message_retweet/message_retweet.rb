# -*- coding: utf-8 -*-
Plugin.create :message_retweet do
  message_fragment :retweeted, "ReTweet" do
    message = retriever

    set_icon Skin.get('retweet.png')
    user_list = Gtk::UserList.new
    begin
      user_list.add_user Users.new(retriever.retweeted_by.to_a)
    rescue => err
    error err
    end
    nativewidget user_list

    on_retweet do |retweets|
      retweets.deach do |retweet|
        break if user_list.destroyed?
        if retweet.retweet_source(true) == message
          user_list.add_user(Users.new([retweet.user])) end end end

    Service.primary.retweeted_users(id: message.id).next{|users|
      user_list.add_user(users)
    }.terminate(_('リツイートしたユーザの一覧が取得できませんでした')).trap {|exception|
      error exception
    }

  end
end
