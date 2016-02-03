# -*- coding: utf-8 -*-

Plugin.create :profile do
  UserConfig[:profile_show_tweet_once] ||= 20
  plugin = self
  def timeline_storage # {slug: user}
    @timeline_storage ||= {} end

  Message::Entity.addlinkrule(:user_mentions, Message::MentionMatcher){ |segment|
    idname = segment[:url].match(Message::MentionExactMatcher)[1]
    user = User.findbyidname(idname)
    if user
      Plugin.call(:show_profile, Service.primary, user)
    else
      Thread.new{
        user = service.scan(:user_show,
                            :no_auto_since_id => false,
                            :screen_name => idname)
        Plugin.call(:show_profile, Service.primary, user) if user } end }

  Delayer.new do
    (UserConfig[:profile_opened_tabs] || []).uniq.each do |user_id|
      retrieve_user(user_id).next{|user|
        user ||= User.findbyid(user_id)
        show_profile(user, true) if user
      }.terminate end end

  def retrieve_user(user_id, services = Service.services.shuffle)
    if services.nil? or services.empty?
      return nil end
    service = services.car
    (service/:users/:show).user(user_id: user_id,
                                cache: false).trap{
      retrieve_user(user_id, services.cdr) } end

  filter_show_filter do |messages|
    muted_users = UserConfig[:muted_users]
    if muted_users && !muted_users.empty?
      [messages.select{ |m| !muted_users.include?(m.idname) && (m.receive_user_screen_names & muted_users).empty? }]
    else
      [messages] end end

  on_show_profile do |service, user|
    show_profile(user) end

  def show_profile(user, force=false)
    slug = "profile-#{user.id}".to_sym
    if !force and Plugin::GUI::Tab.exist?(slug)
      Plugin::GUI::Tab.instance(slug).active!
    else
      UserConfig[:profile_opened_tabs] = ((UserConfig[:profile_opened_tabs] || []) + [user.id]).uniq
      container = profile_head(user)
      i_cluster = tab slug, _("%{user} のプロフィール") % {user: user[:name]} do
        set_icon user[:profile_image_url]
        set_deletable true
        shrink
        nativewidget container
        expand
        profile nil end
      Thread.new {
        Plugin.filtering(:profiletab, [], i_cluster, user).first
      }.next { |tabs|
        tabs.map(&:last).each(&:call)
      }.next {
        Plugin.call(:filter_stream_reconnect_request)
        if !force
          i_cluster.active! end }
    end end

  user_fragment :usertimeline, _("最近のツイート") do
    set_icon Skin.get("timeline.png")
    user_id = retriever.id
    i_timeline = timeline nil do
      order do |message|
        retweet = message.retweeted_statuses.find{ |r| user_id == r.user.id }
        (retweet || message)[:created].to_i end end
    Service.primary.user_timeline(user_id: user_id, include_rts: 1, count: [UserConfig[:profile_show_tweet_once], 200].min).next{ |tl|
      i_timeline << tl
    }.terminate(_("@%{user} の最近のつぶやきが取得できませんでした。見るなってことですかね") % {user: retriever[:idname]})
    timeline_storage[i_timeline.slug] = retriever end

  user_fragment :aboutuser, _("ユーザについて") do
    set_icon retriever[:profile_image_url]
    bio = ::Gtk::IntelligentTextview.new("")
    label_since = ::Gtk::Label.new
    container = ::Gtk::VBox.new.
      closeup(bio).
      closeup(label_since.left).
      closeup(plugin.relation_bar(retriever))
    container.closeup(plugin.mutebutton(retriever)) if not retriever.me?
    scrolledwindow = ::Gtk::ScrolledWindow.new
    scrolledwindow.set_policy(::Gtk::POLICY_AUTOMATIC, ::Gtk::POLICY_AUTOMATIC)
    scrolledwindow.add_with_viewport(container)
    scrolledwindow.style = container.style
    wrapper = Gtk::EventBox.new
    wrapper.no_show_all = true
    wrapper.show
    nativewidget wrapper.add(scrolledwindow)
    wrapper.ssc(:expose_event) do
      wrapper.no_show_all = false
      wrapper.show_all
      false end
    retriever_complete do
      biotext = (user[:detail] || "")
      if user[:url]
        biotext += "\n\n" + _('Web: %{url}') % {url: user[:url]} end
      bio.rewind(biotext)
      ago = (Time.now - (user[:created] or 1)).to_i / (60 * 60 * 24)
      label_since.text = _("Twitter開始: %{year}/%{month}/%{day} %{hour}:%{minute}:%{second} (%{tweets_per_day}tweets/day)") % {
        year: user[:created].strftime('%Y'),
        month: user[:created].strftime('%m'),
        day: user[:created].strftime('%d'),
        hour: user[:created].strftime('%H'),
        minute: user[:created].strftime('%M'),
        second: user[:created].strftime('%S'),
        tweets_per_day: ago == 0 ? user[:statuses_count] : "%.2f" % (user[:statuses_count].to_f / ago)
      } + "\n" end
  end

  on_appear do |messages|
    timeline_storage.dup.deach{ |slug, user|
      messages.each{ |message|
        timeline(slug) << message if message.user == user } } end

  filter_filter_stream_follow do |users|
    [users.merge(timeline_storage.values)] end

  on_gui_destroy do |widget|
    if widget.is_a? Plugin::GUI::Timeline
      timeline_storage.delete(widget.slug)
      UserConfig[:profile_opened_tabs] = timeline_storage.values.map(&:id) end end

  command(:aboutuser,
          name: lambda { |opt|
            if defined? opt.messages.first and opt.messages.first.repliable?
              u = opt.messages.first.user
              (_("%{screen_name}(%{name})について") % {
               screen_name: u[:idname],
               name: u[:name] }).gsub(/_/, '__')
            else
              _("ユーザについて") end },
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
    Mtk::boolean(changer, _('ミュート')) end

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
    Service.each{ |me|
      following = followed = nil
      w_following_label = ::Gtk::Label.new(_("関係を取得中"))
      w_followed_label = ::Gtk::Label.new("")
      w_eventbox_image_following = ::Gtk::EventBox.new
      w_eventbox_image_followed = ::Gtk::EventBox.new
      relation = if me.user_obj == user
                   ::Gtk::Label.new(_("それはあなたです！"))
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
            w_following_label.text = new ? _("ﾌｮﾛｰしている") : _("ﾌｮﾛｰしていない")
            followbutton.label = new ? _("解除") : _("ﾌｮﾛｰ") end }
        # フォローされている状態の更新
        m_followed_refresh = lambda { |new|
          if not w_eventbox_image_followed.destroyed?
            followed = new
            if not w_eventbox_image_followed.children.empty?
              w_eventbox_image_followed.remove(w_eventbox_image_followed.children.first) end
            w_eventbox_image_followed.style = w_eventbox_image_followed.parent.style
            w_eventbox_image_followed.add(::Gtk::WebIcon.new(Skin.get(new ? "arrow_followed.png" : "arrow_notfollowed.png"), arrow_size).show_all)
            w_followed_label.text = new ? _("ﾌｮﾛｰされている") : _("ﾌｮﾛｰされていない") end }
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
              me.__send__(following ? :unfollow : :follow, user_id: user.id).next{ |msg|
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
          w_following_label.text = _("取得できませんでした") } end
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
    }.terminate(_("ふぁぼが取得できませんでした")).trap{
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
