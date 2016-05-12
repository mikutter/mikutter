# -*- coding: utf-8 -*-
Plugin.create :message_retweet do
  error_message_get_retweeted_users = _('リツイートしたユーザの一覧が取得できませんでした')
  message_fragment :retweeted, "ReTweet" do
    message = retriever

    set_icon Skin.get('retweet.png')
    user_list = Gtk::UserList.new
    begin
      user_list.add_user retriever.retweeted_by
    rescue => err
    error err
    end
    nativewidget user_list

    on_retweet do |retweets|
      retweets.deach do |retweet|
        break if user_list.destroyed?
        if retweet.retweet_source(true) == message
          user_list.add_user([retweet.user]) end end end

    user_list.ssc_atonce :expose_event do
      Service.primary.retweeted_users(id: message.id).next{|users|
        user_list.add_user(users)
      }.terminate(error_message_get_retweeted_users).trap {|exception|
        error exception }
      false end
  end

end
