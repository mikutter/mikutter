# -*- coding: utf-8 -*-

Module.new do

  @tabclass = Class.new(Addon.gen_tabclass){
    def initialize(name, service, options = {})
      @page = 1
      options[:header] = Gtk::VBox.new(false, 0)
      super(name, service, options) end

    def suffix
      'のプロフィール' end

    def user
      @options[:user] end

    def on_create
      @appear_event = Plugin::create(:profile).add_event(:appear){ |res|
        unless timeline.destroyed?
          msgs = res.select{ |msg| msg[:user][:id] == user[:id] }
          timeline.add(msgs) if not msgs.empty? end }
      @service.user_timeline(user_id: user[:id], include_rts: 1, count: 20).next{ |tl|
        timeline.add(tl) if not(timeline.destroyed?) and tl
      }.terminate("@#{user[:idname]} の最近のつぶやきが取得できませんでした。見るなってことですかね")
      @service.call_api(:list_user_followers, user_id: user[:id], filter_to_owned_lists: 1){ |res|
        if not(@notebook.destroyed?) and res
          followed_list_ids = res.map{|list| list['id'].to_i}
          locked = {}
          @list = Gtk::ListList.new{ |iter|
            if not locked[iter[1]]
              locked[iter[1]] = true
              flag = iter[0] # = !iter[0]
              list = iter[2]
              @service.__send__(flag ? :delete_list_member : :add_list_member,
                                :list_id => list['id'],
                                :user_id => user[:id]).next{ |result|
                iter[0] = !flag if not(@list.destroyed?)
                locked[iter[1]] = false
                if flag
                  list.remove_member(user)
                  Plugin.call(:list_member_removed, @service, user, list, @service.user_obj)
                else
                  list.add_member(user)
                  Plugin.call(:list_member_added, @service, user, list, @service.user_obj) end
              }.terminate{ |e|
                locked[iter[1]] = false
                "@#{user[:idname]} をリスト #{iter[2]['name']} に追加できませんでした" } end }
          @list.set_auto_get(true){ |list|
            followed_list_ids.include?(list['id'].to_i) }
          @notebook.append_page(@list.show_all,
                                Gtk::WebIcon.new(MUI::Skin.get("list.png"), 16, 16).show_all) end }
      header.closeup(profile).show_all
      super
      focus end

    def on_remove
      super
      Plugin::create(:profile).detach(:appear, @appear_event) end

    private

    def gen_main
      @timeline = Gtk::TimeLine.new
      @notebook = Gtk::Notebook.new.set_tab_pos(Gtk::POS_TOP).set_tab_border(0)
      @notebook.append_page(@timeline,
                            Gtk::WebIcon.new(MUI::Skin.get("timeline.png"), 16, 16).show_all)
      Plugin.filtering(:profile_tab, @notebook, user)
      @header = (@options[:header] or Gtk::HBox.new)
      Gtk::VBox.new(false, 0).closeup(@header).add(@notebook) end

    def background_color
      style = Gtk::Style.new()
      style.set_bg(Gtk::STATE_NORMAL, 0xFF ** 2, 0xFF ** 2, 0xFF ** 2)
      style end

    def relation
      relationbox = Gtk::VBox.new(false, 0)
      if user[:idname] == @service.user
        relationbox.add(Gtk::Label.new('それはあなたです！'))
      else
        @service.friendship(target_id: user[:id], source_id: @service.user_obj[:id]).next{ |rel|
          if rel
            unless(relationbox.destroyed?)
              relationbox.closeup(Gtk::Label.new("#{user[:idname]}はあなたをフォローしていま" +
                                                 if rel[:followed_by] then 'す' else 'せん' end)).
                closeup(followbutton(rel[:user], rel[:following])).
                closeup(mutebutton(rel[:user])).show_all end end }.terminate
      end
      relationbox end

    def profile
      eventbox = Gtk::EventBox.new
      eventbox.signal_connect('visibility-notify-event'){
        eventbox.style = background_color
        false }
      eventbox.add(Gtk::VBox.new(false, 0).
                   closeup(toolbar).
                   add(Gtk::HBox.new(false, 16).
                       closeup(Gtk::WebIcon.new(user[:profile_image_url]).top).
                       add(Gtk::VBox.new(false, 0).add(main(eventbox)).add(relation)))) end

    def followbutton(user, following)
      btn = nil
      changer = lambda{ |new, widget|
        if new === nil
          following
        elsif new != following
          widget.sensitive = false
          @service.method(new ? :follow : :unfollow).call(user){ |event, msg|
            case event
            when :exit
              Plugin.call(new ? :followings_created : :followings_destroy, @service, [user])
              following = new
              Delayer.new{
                unless widget.destroyed?
                  widget.sensitive = true end } end } end }
      btn = Mtk::boolean(changer, 'フォロー') end

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

    def toolbar
      container = Gtk::HBox.new(false, 0)
      close = Gtk::Button.new.add(Gtk::WebIcon.new(MUI::Skin.get('close.png'), 16, 16))
      close.signal_connect('clicked'){
        remove }
      container.closeup(close) end

    def main(window_parent)
      ago = (Time.now - (user[:created] or 1)).to_i / (60 * 60 * 24)
      tags = []
      text = "#{user[:idname]} #{user[:name]}\n"
      append = lambda{ |title, value|
        tags << ['_caption_style', text.size, title.size]
        text << "#{title} #{value}" }
      append.call "location", "#{user[:location]}\n" if user[:location]
      append.call  "web", "#{user[:url]}\n" if user[:url]
      append.call "bio", "#{user[:detail]}\n\n" if user[:detail]
      append.call "フォロー", "#{user[:friends_count]} / "
      append.call "フォロワー", "#{user[:followers_count]} / #{user[:statuses_count]}Tweets " +
        "(#{if ago == 0 then user[:statuses_count] else (user[:statuses_count].to_f / ago).round_at(2) end}/day)\n"
      append.call "since", "#{user[:created].strftime('%Y/%m/%d %H:%M:%S')}" if user[:created]
      body = Gtk::IntelligentTextview.new(text)
      body.buffer.create_tag('_caption_style',
                             'foreground_gdk' => Gdk::Color.new(0, 0x33 ** 2, 0x66 ** 2),
                             'weight' => Pango::FontDescription::WEIGHT_BOLD)
      tags << [tag_user_id_link(body), 0, user[:idname].size]
      tags.each{ |token|
        body.buffer.apply_tag(token[0], *body.buffer.get_range(*token[1..2])) }
      body.get_background = lambda{ background_color }
      body end

    private

    def tag_user_id_link(body)
      tag = body.buffer.create_tag('_user_id_link',
                                   'foreground' => 'blue',
                                   "underline" => Pango::UNDERLINE_SINGLE)
      tag.signal_connect('event'){ |this, textview, event, iter|
        result = false
        if(event.is_a?(Gdk::EventButton)) and
            (event.event_type == Gdk::Event::BUTTON_RELEASE) and
            not(textview.buffer.selection_bounds[2])
          if (event.button == 1)
            Gtk::openurl('http://twitter.com/#!/'+user[:idname]) end
        elsif(event.is_a?(Gdk::EventMotion))
          body.set_cursor(textview, Gdk::Cursor::HAND2) end
        result }
      tag end }

  def self.boot
    plugin = Plugin::create(:profile)
    plugin.add_event(:show_profile){ |service, user|
      makescreen(user, service) }
    plugin.add_event(:boot){ |service|
      set_contextmenu(plugin, service)
      Message::Entity.addlinkrule(:user_mentions, /(?:@|＠|〄|☯|⑨|♨|(?:\W|^)D )[a-zA-Z0-9_]+/){ |segment|
        idname = segment[:url].match(/^(?:@|＠|〄|☯|⑨|♨|(?:\W|^)D )?(.+)$/)[1]
        user = User.findbyidname(idname)
        if user
          makescreen(user, service)
        else
          Thread.new{
            user = service.scan(:user_show,
                                :no_auto_since_id => false,
                                :screen_name => idname)
            Delayer.new{ makescreen(user, service) } if user } end } }
    plugin.add_event_filter(:show_filter){ |messages|
      muted_users = UserConfig[:muted_users]
      if muted_users && !muted_users.empty?
        [messages.select{ |m| !muted_users.include?(m.idname) && (m.receive_user_screen_names & muted_users).empty? }]
      else
        [messages] end } end

  private

  def self.set_contextmenu(plugin, service)

    plugin.add_event_filter(:command){ |menu|
      menu[:show_profile] = {
        :slug => :show_profile,
        :name => 'ユーザについて',
        :show_face => lambda{ |m|
          u = if(m.message[:retweet])
                m.message[:retweet].user
              else
                m.message.user end
          "#{u[:idname]}(#{u[:name]})について".gsub(/_/, '__') },
        :condition => lambda{ |m| m.message.repliable? },
        :exec => lambda{ |m|
          user = if(m.is_a? User)
                   m
                 elsif(m.message[:retweet])
                   m.message[:retweet].user
                 else
                   m.message.user end
          makescreen(user, service) },
        :visible => true,
        :role => :message }
      [menu]
    }

    return

    plugin.add_event_filter(:contextmenu){ |menu|
      menu << [lambda{ |m, w|
                 if(nil == m and nil == w)
                   'ユーザについて'
                 else
                 u = if(m.message[:retweet])
                       m.message[:retweet].user
                     else
                       m.message.user end
                 "#{u[:idname]}(#{u[:name]})について".gsub(/_/, '__') end },
               lambda{ |m, w| m.message.repliable? },
               lambda{ |m, w|
                 user = if(m.message[:retweet]) then m.message[:retweet].user else m.message.user end
                 makescreen(user, service) } ]
      [menu] }
  end

  def self.makescreen(user, service)
    if user[:exact]
      @tabclass.new("#{user[:idname]}(#{user[:name]})", service,
                    :user => user,
                    :icon => user[:profile_image_url])
    else
      service.user_show(id: user[:id], cache: :keep).next{ |new_user|
        raise "inexact user data" if not new_user[:exact]
        makescreen(new_user, service) if new_user.is_a? User }.terminate("@#{user[:idname]}の情報が取得できませんでした")
    end end

  boot
end
