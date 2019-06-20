# -*- coding: utf-8 -*-
Plugin.create :message_retweet do
  error_message_get_retweeted_users = _('リツイートしたユーザの一覧が取得できませんでした')
  message_fragment :retweeted, "ReTweet" do
    message = model

    set_icon Skin[:retweet]
    user_list = Gtk::UserList.new
    begin
      user_list.add_user message.retweeted_by
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
      twitter = Enumerator.new { |y|
        Plugin.filtering(:worlds, y)
      }.select { |world|
        world.class.slug == :twitter
      }.first
      if twitter
        twitter.retweeted_users(id: message.id).next { |users|
          user_list.add_user(users)
        }.terminate(error_message_get_retweeted_users).trap do |exception|
          error exception
        end
      end
      false
    end
  end

end
