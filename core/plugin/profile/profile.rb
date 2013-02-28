# -*- coding: utf-8 -*-

Plugin.create :profile do
  UserConfig[:profile_show_tweet_once] ||= 20
  @counter = gen_counter
  plugin = self
  timeline_storage = {}                # {slug: user}

  Message::Entity.addlinkrule(:user_mentions, /(?:@|＠|〄|☯|⑨|♨|(?:\W|^)D )[a-zA-Z0-9_]+/){ |segment|
    idname = segment[:url].match(/^(?:@|＠|〄|☯|⑨|♨|(?:\W|^)D )?(.+)$/)[1]
    user = User.findbyidname(idname)
    if user
      Plugin.call(:show_profile, Service.primary, user)
    else
      Thread.new{
        user = service.scan(:user_show,
                            :no_auto_since_id => false,
                            :screen_name => idname)
        Plugin.call(:show_profile, Service.primary, user) if user } end }

  filter_show_filter do |messages|
    muted_users = UserConfig[:muted_users]
    if muted_users && !muted_users.empty?
      [messages.select{ |m| !muted_users.include?(m.idname) && (m.receive_user_screen_names & muted_users).empty? }]
    else
      [messages] end end

  on_show_profile do |service, user|
    container = profile_head(user)
    i_profile = tab nil, "#{user[:name]} のプロフィール" do
      set_icon user[:profile_image_url]
      set_deletable true
      shrink
      nativewidget container
      expand
      profile nil end
    Plugin.call(:profiletab, i_profile, user)
    Plugin.call(:filter_stream_reconnect_request)
  end

  profiletab :usertimeline, "最近のツイート" do
    set_icon Skin.get("timeline.png")
    i_timeline = timeline nil
    Service.primary.user_timeline(user_id: user[:id], include_rts: 1, count: [UserConfig[:profile_show_tweet_once], 200].min).next{ |tl|
      i_timeline << tl
    }.terminate("@#{user[:idname]} の最近のつぶやきが取得できませんでした。見るなってことですかね")
    timeline_storage[i_timeline.slug] = user
    i_timeline.active! end

  profiletab :aboutuser, "ユーザについて" do
    set_icon user[:profile_image_url]
    bio = ::Gtk::IntelligentTextview.new("")
    label_since = ::Gtk::Label.new
    container = ::Gtk::VBox.new.
      closeup(bio).
      closeup(label_since.left).
      closeup(plugin.relation_bar(user))
    container.closeup(plugin.mutebutton(user)) if not user.is_me?
    scrolledwindow = ::Gtk::ScrolledWindow.new
    scrolledwindow.set_policy(::Gtk::POLICY_AUTOMATIC, ::Gtk::POLICY_AUTOMATIC)
    scrolledwindow.add_with_viewport(container)
    scrolledwindow.style = container.style
    nativewidget scrolledwindow.show_all
    user_complete do
      biotext = (user[:detail] || "")
      if user[:url]
        biotext += "\n\nWeb: " + user[:url] end
      bio.rewind(biotext)
      ago = (Time.now - (user[:created] or 1)).to_i / (60 * 60 * 24)
      label_since.text = "Twitter開始: #{user[:created].strftime('%Y/%m/%d %H:%M:%S')} (#{ago == 0 ? user[:statuses_count] : (user[:statuses_count].to_f / ago).round_at(2)}tweet/day)\n" end
  end

  on_appear do |messages|
    timeline_storage.dup.deach{ |slug, user|
      messages.each{ |message|
        timeline(slug) << message if message.user == user } } end

  filter_filter_stream_follow do |users|
    [users.merge(timeline_storage.values)] end

  on_gui_destroy do |widget|
    if widget.is_a? Plugin::GUI::Timeline
      timeline_storage.delete(widget.slug) end end

  command(:aboutuser,
          name: lambda { |opt|
            if defined? opt.messages.first and opt.messages.first.repliable?
              u = opt.messages.first.user
              "#{u[:idname]}(#{u[:name]})について".gsub(/_/, '__')
            else
             "ユーザについて" end },
          condition: Plugin::Command::CanReplyAll,
          visible: true,
          icon: lambda{ |opt| opt && opt.messages.first.user[:profile_image_url] },
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
    icon_size = Gdk::Rectangle.new(0, 0, 32, 32)
    arrow_size = Gdk::Rectangle.new(0, 0, 16, 16)
    container = ::Gtk::VBox.new(false, 4)
    Service.all.each{ |me|
      following = followed = nil
      w_following_label = ::Gtk::Label.new("関係を取得中")
      w_followed_label = ::Gtk::Label.new("")
      w_eventbox_image_following = ::Gtk::EventBox.new
      w_eventbox_image_followed = ::Gtk::EventBox.new
      relation = if me.user_obj == user
                   ::Gtk::Label.new("それはあなたです！")
                 else
                   ::Gtk::HBox.new.
                     closeup(w_eventbox_image_following).
                     closeup(w_following_label) end
      relation_container = ::Gtk::HBox.new(false, icon_size.width/2)
      relation_container.closeup(::Gtk::WebIcon.new(me.user_obj[:profile_image_url], icon_size).tooltip("#{me.user}(#{me.user_obj[:name]})"))
      relation_container.closeup(::Gtk::VBox.new.
                                 closeup(relation).
                                 closeup(::Gtk::HBox.new.
                                         closeup(w_eventbox_image_followed).
                                         closeup(w_followed_label)))
      relation_container.closeup(::Gtk::WebIcon.new(user[:profile_image_url], icon_size).tooltip("#{user.idname}(#{user[:name]})"))
      if me.user_obj != user
        followbutton = ::Gtk::Button.new
        followbutton.sensitive = false
        # フォローしている状態の更新
        m_following_refresh = lambda { |new|
          if not w_eventbox_image_following.destroyed?
            following = new
            if not w_eventbox_image_following.children.empty?
              w_eventbox_image_following.remove(w_eventbox_image_following.children.first) end

            w_eventbox_image_following.style = w_eventbox_image_following.parent.style
            w_eventbox_image_following.add(::Gtk::WebIcon.new(Skin.get(new ? "arrow_following.png" : "arrow_notfollowing.png"), arrow_size).show_all)
            w_following_label.text = new ? "ﾌｮﾛｰしている" : "ﾌｮﾛｰしていない"
            followbutton.label = new ? "解除" : "ﾌｮﾛｰ" end }
        # フォローされている状態の更新
        m_followed_refresh = lambda { |new|
          if not w_eventbox_image_followed.destroyed?
            followed = new
            if not w_eventbox_image_followed.children.empty?
              w_eventbox_image_followed.remove(w_eventbox_image_followed.children.first) end
            w_eventbox_image_followed.style = w_eventbox_image_followed.parent.style
            w_eventbox_image_followed.add(::Gtk::WebIcon.new(Skin.get(new ? "arrow_followed.png" : "arrow_notfollowed.png"), arrow_size).show_all)
            w_followed_label.text = new ? "ﾌｮﾛｰされている" : "ﾌｮﾛｰされていない" end }
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
                Plugin.call(event, me, Users.new([user]))
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
          w_following_label.text = "取得できませんでした" } end
      container.closeup(relation_container.closeup(followbutton)) }
    container end

  # ユーザのプロフィールのヘッダ部を返す
  # ==== Args
  # [user] 表示するUser
  # ==== Return
  # ヘッダ部を表すGtkコンテナ
  def profile_head(user)
    eventbox = ::Gtk::EventBox.new
    eventbox.ssc('visibility-notify-event'){
      eventbox.style = background_color
      false }
    eventbox.add(::Gtk::VBox.new(false, 0).
                 add(::Gtk::HBox.new(false, 16).
                     closeup(::Gtk::WebIcon.new(user.profile_image_url_large, 128, 128).top).
                     closeup(::Gtk::VBox.new.closeup(user_name(user)).closeup(profile_table(user)))))
    scrolledwindow = ::Gtk::ScrolledWindow.new
    scrolledwindow.height_request = 128 + 24
    scrolledwindow.set_policy(::Gtk::POLICY_AUTOMATIC, ::Gtk::POLICY_NEVER)
    scrolledwindow.add_with_viewport(eventbox)
  end

  # ユーザ名を表示する
  # ==== Args
  # [user] 表示するUser
  # ==== Return
  # ユーザの名前の部分のGtkコンテナ
  def user_name(user)
    w_screen_name = ::Gtk::Label.new.set_markup("<b><u><span foreground=\"#0000ff\">#{Pango.escape(user[:idname])}</span></u></b>")
    w_ev = ::Gtk::EventBox.new
    w_ev.modify_bg(::Gtk::STATE_NORMAL, Gdk::Color.new(0xffff, 0xffff, 0xffff))
    w_ev.ssc(:realize) {
      w_ev.window.set_cursor(Gdk::Cursor.new(Gdk::Cursor::HAND2))
      false }
    w_ev.ssc(:button_press_event) { |this, e|
      if e.button == 1
        ::Gtk.openurl("http://twitter.com/#{user[:idname]}")
        true end }
    ::Gtk::HBox.new(false, 16).closeup(w_ev.add(w_screen_name)).closeup(::Gtk::Label.new(user[:name]))
  end

  # プロフィールの上のところの格子になってる奴をかえす
  # ==== Args
  # [user] 表示するUser
  # ==== Return
  # プロフィールのステータス部を表すGtkコンテナ
  def profile_table(user)
    w_tweets = ::Gtk::Label.new(user[:statuses_count].to_s)
    w_favs = ::Gtk::Label.new(user[:favourites_count].to_s)
    w_faved = ::Gtk::Label.new("...")
    w_followings = ::Gtk::Label.new(user[:friends_count].to_s)
    w_followers = ::Gtk::Label.new(user[:followers_count].to_s)
    user.count_favorite_by.next{ |favs|
      w_faved.text = favs.to_s
    }.terminate("ふぁぼが取得できませんでした").trap{
      w_faved.text = '-' }
    ::Gtk::Table.new(2, 5).
      attach(w_tweets.right, 0, 1, 0, 1).
      attach(::Gtk::Label.new("tweets").left, 1, 2, 0, 1).
      attach(w_favs.right, 0, 1, 1, 2).
      attach(::Gtk::Label.new("favs").left, 1, 2, 1, 2).
      attach(w_faved.right, 0, 1, 2, 3).
      attach(::Gtk::Label.new("faved").left, 1, 2, 2, 3).
      attach(w_followings.right, 0, 1, 3, 4).
      attach(::Gtk::Label.new("followings").left, 1, 2, 3, 4).
      attach(w_followers.right, 0, 1, 4, 5).
      attach(::Gtk::Label.new("followers").left, 1, 2, 4, 5).
      set_row_spacing(0, 4).
      set_row_spacing(1, 4).
      set_column_spacing(0, 16)
  end

  def background_color
    style = ::Gtk::Style.new()
    style.set_bg(::Gtk::STATE_NORMAL, 0xFF ** 2, 0xFF ** 2, 0xFF ** 2)
    style end
end
