# -*- coding: utf-8 -*-

Plugin.create :profile do
  UserConfig[:profile_show_tweet_once] ||= 20
  @counter = gen_counter
  plugin = self
  timeline_storage = {}                # {slug: {timeline, user}}

  on_show_profile do |service, user|
    container = profile_head(user)
    i_profile = nil
    i_tab = tab nil, "#{user[:name]} のプロフィール}" do
      set_icon user[:profile_image_url]
      shrink
      nativewidget container
      expand
      i_profile = profile slug end
    Plugin.call(:profiletab, i_profile, user)
  end

  profiletab :usertimeline, "最近のツイート" do
    set_icon MUI::Skin.get("timeline.png")
    i_timeline = timeline nil
    Service.primary.user_timeline(user_id: user[:id], include_rts: 1, count: [UserConfig[:profile_show_tweet_once], 200].min).next{ |tl|
      i_timeline << tl
    }.terminate("@#{user[:idname]} の最近のつぶやきが取得できませんでした。見るなってことですかね")
    timeline_storage[i_timeline.slug] = {timeline: i_timeline, user: user}.freeze end

  profiletab :aboutuser, "ユーザについて" do
    set_icon user[:profile_image_url]
    bio = Gtk::IntelligentTextview.new(user[:detail])
    ago = (Time.now - (user[:created] or 1)).to_i / (60 * 60 * 24)
    nativewidget Gtk::VBox.new.
      closeup(bio).
      closeup(Gtk::Label.new("Twitter開始: #{user[:created].strftime('%Y/%m/%d %H:%M:%S')} (#{ago == 0 ? user[:statuses_count] : (user[:statuses_count].to_f / ago).round_at(2)}tweet/day)\n").left).
      closeup(plugin.relation_bar(user)).
      closeup(plugin.mutebutton(user)).show_all end

  on_appear do |messages|
    timeline_storage.dup.deach{ |tl|
      messages.each{ |message|
        tl.timeline << message if message.user == tl.user } } end

  on_gui_destroy do |widget|
    if widget.is_a? Plugin::GUI::Timeline
      timeline_storage.delete(widget.slug) end end

  command(:aboutuser,
          name: lambda { |opt|
            if defined? opt.messages.first and opt.messages.first.repliable?
              u = opt.messages.first.user
              "#{u[:idname]}(#{u[:name]})について".gsub(/_/, '__') end },
          condition: lambda{ |opt| opt.messages.first.repliable? },
          visible: true,
          role: :timeline) do |opt|
    Plugin.call(:show_profile, Service.primary, opt.messages.first.user) end

  def mutebutton(user)
    changer = lambda{ |new, widget|
      if new === nil
        UserConfig[:muted_users] and UserConfig[:muted_users].include?(user.idname)
      elsif new
        add_muted_user(user)
      else
        remove_muted_user(user)
      end
    }
    btn = Mtk::boolean(changer, 'ミュート')
  end

  def add_muted_user(user)
    type_strict user => User
    atomic{
      muted = (UserConfig[:muted_users] ||= []).melt
      muted << user.idname
      UserConfig[:muted_users] = muted } end

  def remove_muted_user(user)
    type_strict user => User
    atomic{
      muted = (UserConfig[:muted_users] ||= []).melt
      muted.delete(user.idname)
      UserConfig[:muted_users] = muted } end

  # フォロー関係を表示する
  # ==== Args
  # [user] 対象となるユーザ
  # ==== Return
  # リレーションバーのウィジェット(Gtk::VBox)
  def relation_bar(user)
    icon_size = Gdk::Rectangle.new(0, 0, 16, 16)
    container = Gtk::VBox.new(false, 4)
    Service.all.each{ |me|
      following = followed = nil
      w_following_label = Gtk::Label.new("関係を取得中")
      w_followed_label = Gtk::Label.new("")
      w_eventbox_image_following = Gtk::EventBox.new
      w_eventbox_image_followed = Gtk::EventBox.new
      followbutton = Gtk::Button.new
      followbutton.sensitive = false
      # フォローしている状態の更新
      m_following_refresh = lambda { |new|
        if not w_eventbox_image_following.destroyed?
          following = new
          if not w_eventbox_image_following.children.empty?
            w_eventbox_image_following.remove(w_eventbox_image_following.children.first) end
          w_eventbox_image_following.add(Gtk::WebIcon.new(MUI::Skin.get(new ? "arrow_following.png" : "arrow_notfollowing.png"), icon_size).show_all)
          w_following_label.text = new ? "ﾌｮﾛｰしている" : "ﾌｮﾛｰしていない"
          followbutton.label = new ? "解除" : "ﾌｮﾛｰ" end }
      # フォローされている状態の更新
      m_followed_refresh = lambda { |new|
        if not w_eventbox_image_followed.destroyed?
          followed = new
          if not w_eventbox_image_followed.children.empty?
            w_eventbox_image_followed.remove(w_eventbox_image_followed.children.first) end
          w_eventbox_image_followed.add(Gtk::WebIcon.new(MUI::Skin.get(new ? "arrow_followed.png" : "arrow_notfollowed.png"), icon_size).show_all)
          w_followed_label.text = new ? "ﾌｮﾛｰされている" : "ﾌｮﾛｰされていない" end }

      container.closeup(Gtk::HBox.new(false, icon_size.width).
                        closeup(Gtk::WebIcon.new(me.user_obj[:profile_image_url], icon_size)).
                        closeup(Gtk::HBox.new.
                                closeup(w_eventbox_image_following).
                                closeup(w_following_label)).
                        closeup(Gtk::HBox.new.
                                closeup(w_eventbox_image_followed).
                                closeup(w_followed_label)).
                        closeup(Gtk::WebIcon.new(user[:profile_image_url], icon_size)).
                        closeup(followbutton))
      Service.primary.friendship(target_id: user[:id], source_id: me.user_obj[:id]).next{ |rel|
        if rel and not(w_eventbox_image_following.destroyed?)
          m_following_refresh.call(rel[:following])
          m_followed_refresh.call(rel[:followed_by])
          handler_followings_created = on_followings_created do |service, dst_users|
            if service == me and dst_users.include?(user)
              m_following_refresh.call(true) end end
          handler_followings_destroy = on_followings_destroy do |service, dst_users|
            if service == me and dst_users.include?(user)
              m_following_refresh.call(false) end end
          followbutton.ssc(:clicked){
            followbutton.sensitive = false
            event = following ? :followings_destroy : :followings_created
            me.__send__(following ? :unfollow : :follow, user).next{ |msg|
              Plugin.call(event, me, [user])
              followbutton.sensitive = true unless followbutton.destroyed? }.
            terminate.trap{
              followbutton.sensitive = true unless followbutton.destroyed? }
            true }
          followbutton.signal_connect(:destroy){
            detach(:followings_created, handler_followings_created)
            detach(:followings_destroy, handler_followings_destroy)
            false }
          followbutton.sensitive = true end
      }.terminate.trap{
        w_following_label.text = "取得できませんでした" } }
    container end

  # ユーザのプロフィールのヘッダ部を返す
  # ==== Args
  # [user] 表示するUser
  # ==== Return
  # ヘッダ部を表すGtkコンテナ
  def profile_head(user)
    eventbox = Gtk::EventBox.new
    eventbox.ssc('visibility-notify-event'){
      eventbox.style = background_color
      false }
    eventbox.add(Gtk::VBox.new(false, 0).
                 # closeup(toolbar).
                 add(Gtk::HBox.new(false, 16).
                     closeup(Gtk::WebIcon.new(user[:profile_image_url], 128, 128).top).
                     closeup(Gtk::VBox.new.closeup(user_name(user)).closeup(profile_table(user))))) end

  # ユーザ名を表示する
  # ==== Args
  # [user] 表示するUser
  # ==== Return
  # ユーザの名前の部分のGtkコンテナ
  def user_name(user)
    Gtk::HBox.new(false, 16).closeup(Gtk::Label.new.set_markup("<b>#{Pango.escape(user[:idname])}</b>")).closeup(Gtk::Label.new(user[:name]))
  end

  # プロフィールの上のところの格子になってる奴をかえす
  # ==== Args
  # [user] 表示するUser
  # ==== Return
  # プロフィールのステータス部を表すGtkコンテナ
  def profile_table(user)
    w_tweets = Gtk::Label.new(user[:statuses_count].to_s)
    w_favs = Gtk::Label.new(user[:favourites_count].to_s)
    w_faved = Gtk::Label.new("...")
    w_followings = Gtk::Label.new(user[:friends_count].to_s)
    w_followers = Gtk::Label.new(user[:followers_count].to_s)
    user.count_favorite_by.next{ |favs|
      w_faved.text = favs.to_s
    }.terminate("ふぁぼが取得できませんでした").trap{
      w_faved.text = '-' }
    Gtk::Table.new(2, 3).
      attach(Gtk::HBox.new(false, 4).add(w_tweets).closeup(Gtk::Label.new("tweets").right), 0, 1, 0, 1).
      attach(Gtk::HBox.new(false, 4).add(w_favs).closeup(Gtk::Label.new("favs").right), 0, 1, 1, 2).
      attach(Gtk::HBox.new(false, 4).add(w_faved).closeup(Gtk::Label.new("faved").right), 1, 2, 1, 2).
      attach(Gtk::HBox.new(false, 4).add(w_followings).closeup(Gtk::Label.new("followings").right), 0, 1, 2, 3).
      attach(Gtk::HBox.new(false, 4).add(w_followers).closeup(Gtk::Label.new("followers").right), 1, 2, 2, 3).
      set_row_spacing(0, 4).
      set_row_spacing(1, 4).
      set_column_spacing(0, 16)
  end

  def background_color
    style = Gtk::Style.new()
    style.set_bg(Gtk::STATE_NORMAL, 0xFF ** 2, 0xFF ** 2, 0xFF ** 2)
    style end
end
