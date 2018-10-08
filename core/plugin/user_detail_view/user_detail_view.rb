# -*- coding: utf-8 -*-

Plugin.create :user_detail_view do
  UserConfig[:profile_show_tweet_once] ||= 20
  UserConfig[:profile_icon_size] ||= 64
  UserConfig[:profile_icon_margin] ||= 8

  intent :twitter_user, label: _('プロフィール') do |intent_token|
    show_profile(intent_token.model, intent_token)
  end

  plugin = self
  def timeline_storage # {slug: user}
    @timeline_storage ||= {} end

  Delayer.new do
    (UserConfig[:profile_opened_tabs] || []).uniq.each do |user_id|
      retrieve_user(user_id)&.next{|user|
        user ||= User.findbyid(user_id)
        show_profile(user, nil, true) if user
      }&.terminate end end

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
      tweets, else_messages = messages.partition{|m| m.class.slug == :twitter_tweet }
      [ tweets.select{ |m| !muted_users.include?(m.idname) && (m.receive_user_screen_names & muted_users).empty? } + else_messages ]
    else
      [messages] end end

  # 互換性のため。
  # openイベントを使おう
  on_show_profile do |service, user|
    Plugin.call(:open, user) end

  def show_profile(user, token, force=false)
    slug = "profile-#{user.uri}".to_sym
    if !force and Plugin::GUI::Tab.exist?(slug)
      Plugin::GUI::Tab.instance(slug).active!
    else
      UserConfig[:profile_opened_tabs] = ((UserConfig[:profile_opened_tabs] || []) + [user.id]).uniq
      container = profile_head(user, token)
      i_cluster = tab slug, _("%{user} のプロフィール") % {user: user[:name]} do
        set_icon user.icon
        set_deletable true
        shrink
        nativewidget container
        expand
        cluster nil end
      Thread.new {
        Plugin.filtering(:user_detail_view_fragments, [], i_cluster, user).first
      }.next { |tabs|
        tabs.map(&:last).each(&:call)
      }.next {
        Plugin.call(:filter_stream_reconnect_request)
        if !force
          i_cluster.active! end
      }.terminate(_("%{user} のプロフィールの取得中にエラーが発生しました。見るなってことですかね。") % {user: user.name})
    end end

  user_fragment :usertimeline, _("最近のツイート") do
    set_icon Skin['timeline.png']
    user_id = model.id
    i_timeline = timeline nil do
      order do |message|
        retweet = message.retweeted_statuses.find{ |r| user_id == r.user.id }
        (retweet || message)[:created].to_i end end
    Enumerator.new{|y|
      Plugin.filtering(:worlds, y)
    }.select{|world|
      world.class.slug == :twitter
    }.first.user_timeline(user_id: user_id, include_rts: 1, count: [UserConfig[:profile_show_tweet_once], 200].min).next{ |tl|
      i_timeline << tl
    }.terminate(_("@%{user} の最近のつぶやきが取得できませんでした。見るなってことですかね") % {user: model[:idname]})
    timeline_storage[i_timeline.slug] = model end

  user_fragment :aboutuser, _("ユーザについて") do
    set_icon model.icon
    bio = ::Gtk::IntelligentTextview.new("")
    container = ::Gtk::VBox.new.
      closeup(bio).
      closeup(plugin.relation_bar(model))
    container.closeup(plugin.mutebutton(model)) if not model.me?
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
    model_complete do
      biotext = (model[:detail] || "")
      if model[:url]
        biotext += "\n\n" + _('Web: %{url}') % {url: model[:url]} end
      ago = (Time.now - (model[:created] or 1)).to_i / (60 * 60 * 24)
      text_since = _("Twitter開始: %{year}/%{month}/%{day} %{hour}:%{minute}:%{second} (%{tweets_per_day}tweets/day)") % {
        year: model[:created].strftime('%Y'),
        month: model[:created].strftime('%m'),
        day: model[:created].strftime('%d'),
        hour: model[:created].strftime('%H'),
        minute: model[:created].strftime('%M'),
        second: model[:created].strftime('%S'),
        tweets_per_day: ago == 0 ? model[:statuses_count] : "%.2f" % (model[:statuses_count].to_f / ago)
      }
      bio.rewind("#{biotext}\n#{text_since}")
    end
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
    Enumerator.new{|y|
      Plugin.filtering(:worlds, y)
    }.select{|world|
      world.class.slug == :twitter
    }.each{ |me|
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
      relation_container.closeup(::Gtk::WebIcon.new(me.user_obj.icon, icon_size).tooltip("#{me.user_obj.idname}(#{me.user_obj[:name]})"))
      relation_container.closeup(::Gtk::VBox.new.
                                 closeup(relation).
                                 closeup(::Gtk::HBox.new.
                                         closeup(w_eventbox_image_followed).
                                         closeup(w_followed_label)))
      relation_container.closeup(::Gtk::WebIcon.new(user.icon, icon_size).tooltip("#{user.idname}(#{user[:name]})"))
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
            w_eventbox_image_following.add(::Gtk::WebIcon.new(Skin[new ? 'arrow_following.png' : 'arrow_notfollowing.png'], arrow_size).show_all)
            w_following_label.text = new ? _("ﾌｮﾛｰしている") : _("ﾌｮﾛｰしていない")
            followbutton.label = new ? _("解除") : _("ﾌｮﾛｰ") end }
        # フォローされている状態の更新
        m_followed_refresh = lambda { |new|
          if not w_eventbox_image_followed.destroyed?
            followed = new
            if not w_eventbox_image_followed.children.empty?
              w_eventbox_image_followed.remove(w_eventbox_image_followed.children.first) end
            w_eventbox_image_followed.style = w_eventbox_image_followed.parent.style
            w_eventbox_image_followed.add(::Gtk::WebIcon.new(Skin.get_path(new ? "arrow_followed.png" : "arrow_notfollowed.png"), arrow_size).show_all)
            w_followed_label.text = new ? _("ﾌｮﾛｰされている") : _("ﾌｮﾛｰされていない") end }
        me.friendship(target_id: user[:id], source_id: me.user_obj[:id]).next{ |rel|
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
                Plugin.call(event, me, [user])
                followbutton.sensitive = true unless followbutton.destroyed? }.
              terminate.trap{
                followbutton.sensitive = true unless followbutton.destroyed? }
              true }
            followbutton.signal_connect(:destroy){
              detach(:followings_created, handler_followings_created)
              detach(:followings_destroy, handler_followings_destroy)
              false }
            followbutton.sensitive = true
            relation_container.closeup(followbutton) end
        }.terminate.trap{
          w_following_label.text = _("取得できませんでした") } end
      container.closeup(relation_container) }
    container end

  # ユーザのプロフィールのヘッダ部を返す
  # ==== Args
  # [user] 表示するUser
  # [intent_token] ユーザを開くときに利用するIntent
  # ==== Return
  # ヘッダ部を表すGtkコンテナ
  def profile_head(user, intent_token)
    eventbox = ::Gtk::EventBox.new
    eventbox.ssc('visibility-notify-event'){
      eventbox.style = background_color
      false }

    icon = ::Gtk::EventBox.new.add(::Gtk::WebIcon.new(user.icon_large, UserConfig[:profile_icon_size], UserConfig[:profile_icon_size]).tooltip(_('アイコンを開く')))
    icon.ssc(:button_press_event) do |this, event|
      Plugin.call(:open, user.icon_large)
      true end
    icon.ssc(:realize) do |this|
      this.window.set_cursor(Gdk::Cursor.new(Gdk::Cursor::HAND2))
      false end

    icon_alignment = Gtk::Alignment.new(0.5, 0, 0, 0)
                     .set_padding(*[UserConfig[:profile_icon_margin]]*4)

    eventbox.add(::Gtk::VBox.new(false, 0).
                  add(::Gtk::HBox.new.
                       closeup(icon_alignment.add(icon)).
                       add(::Gtk::VBox.new.closeup(user_name(user, intent_token)).closeup(profile_table(user)))))
  end

  # ユーザ名を表示する
  # ==== Args
  # [user] 表示するUser
  # [intent_token] ユーザを開くときに利用するIntent
  # ==== Return
  # ユーザの名前の部分のGtkコンテナ
  def user_name(user, intent_token)
    w_name = ::Gtk::TextView.new
    w_name.editable = false
    w_name.cursor_visible = false
    w_name.wrap_mode = Gtk::TextTag::WRAP_CHAR
    w_name.ssc(:event) do |this, event|
      if event.is_a? ::Gdk::EventMotion
        this.get_window(::Gtk::TextView::WINDOW_TEXT)
          .set_cursor(::Gdk::Cursor.new(::Gdk::Cursor::XTERM)) end
      false end
    if Gtk::BINDING_VERSION >= [3,1,2]
      tag_sn = w_name.buffer.create_tag('sn', {foreground: '#0000ff',
                                               weight: Pango::Weight::BOLD,
                                               underline: Pango::Underline::SINGLE})
    else
      tag_sn = w_name.buffer.create_tag('sn', {foreground: '#0000ff',
                                               weight: Pango::FontDescription::WEIGHT_BOLD,
                                               underline: Pango::AttrUnderline::SINGLE})
    end
    tag_sn.ssc(:event, &user_screen_name_event_callback(user, intent_token))

    w_name.buffer.insert(w_name.buffer.start_iter, user[:idname], tag_sn)
    w_name.buffer.insert(w_name.buffer.end_iter, "\n#{user[:name]}")
    Gtk::VBox.new.add(w_name) end

  # プロフィールの上のところの格子になってる奴をかえす
  # ==== Args
  # [user] 表示するUser
  # ==== Return
  # プロフィールのステータス部を表すGtkコンテナ
  def profile_table(user)
    _, profile_columns = Plugin.filtering(:user_detail_view_header_columns, user, [
                                            ['tweets',     user[:statuses_count].to_s],
                                            ['favs',       user[:favourites_count].to_s],
                                            ['followings', user[:friends_count]],
                                            ['followers',  user[:followers_count]],
                                          ])
    ::Gtk::Table.new(2, profile_columns.size).tap{|table|
      profile_columns.each_with_index do |column, index|
        key, value = column
        table.
          attach(::Gtk::Label.new(value.to_s).right, 0, 1, index, index+1).
          attach(::Gtk::Label.new(key.to_s)  .left , 1, 2, index, index+1)
      end
    }.set_row_spacing(0, 4).
      set_row_spacing(1, 4).
      set_column_spacing(0, 16)
  end

  def background_color
    style = ::Gtk::Style.new()
    style.set_bg(::Gtk::STATE_NORMAL, 0xFF ** 2, 0xFF ** 2, 0xFF ** 2)
    style end

  def user_screen_name_event_callback(user, intent_token)
    lambda do |tag, textview, event, iter|
      case event
      when ::Gdk::EventButton
        if event.event_type == ::Gdk::Event::BUTTON_RELEASE and event.button == 1
          if intent_token.respond_to?(:forward)
            intent_token.forward
          else
            Plugin.call(:open, user.uri)
          end
          next true
        end
      when ::Gdk::EventMotion
        textview
          .get_window(::Gtk::TextView::WINDOW_TEXT)
          .set_cursor(::Gdk::Cursor.new(::Gdk::Cursor::HAND2))
      end
      false
    end
  end
end
