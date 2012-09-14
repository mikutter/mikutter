# -*- coding: utf-8 -*-

require File.expand_path File.join(File.dirname(__FILE__), 'profiletab')
require File.expand_path File.join(File.dirname(__FILE__), 'profilenotebook')

Plugin.create :profile do
  UserConfig[:profile_show_tweet_once] ||= 20

  on_show_profile do |service, user|
    # slug = "prifile-#{user['idname']}".to_sym
    container = Gtk::VBox.new.closeup(profile_head(user)).add(tab_container(user))
    tab nil, "#{user['name']} のプロフィール}" do
      set_icon user[:profile_image_url]
      nativewidget container
    end

    # @service.user_timeline(user_id: user[:id], include_rts: 1, count: [UserConfig[:profile_show_tweet_once], 200].min).next{ |tl|
    #   timeline.add(tl) if not(timeline.destroyed?) and tl
    # }.terminate("@#{user[:idname]} の最近のつぶやきが取得できませんでした。見るなってことですかね")
  end

  profiletab :aboutuser, "ユーザについて" do |user|
    # set_icon user[:profile_image_url]
    bio = Gtk::IntelligentTextview.new(user[:detail])
    bio.get_background = method(:background_color)
    Gtk::VBox.new.
      closeup(bio).
      closeup(relation_bar(user))
  end

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

  # プロフィールの上のoところの格子になってる奴をかえす
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
      attach(Gtk::HBox.new(false, 4).add(w_tweets).closeup(Gtk::Label.new("tweets")), 0, 1, 0, 1).
      attach(Gtk::HBox.new(false, 4).add(w_favs).closeup(Gtk::Label.new("favs")), 0, 1, 1, 2).
      attach(Gtk::HBox.new(false, 4).add(w_faved).closeup(Gtk::Label.new("faved")), 1, 2, 1, 2).
      attach(Gtk::HBox.new(false, 4).add(w_followings).closeup(Gtk::Label.new("followings")), 0, 1, 2, 3).
      attach(Gtk::HBox.new(false, 4).add(w_followers).closeup(Gtk::Label.new("followers")), 1, 2, 2, 3).
      set_row_spacing(0, 4).
      set_row_spacing(1, 4).
      set_column_spacing(0, 16)
  end

  # ユーザ情報のタブ
  # ==== Args
  # [user] 表示するUser
  # ==== Return
  # ユーザ情報のタブ(Gtk::ProfileNotebook)
  def tab_container(user)
    notebook = Gtk::ProfileNotebook.new
    Plugin.filtering(:profiletab, notebook, user)
    notebook
  end

  def background_color
    style = Gtk::Style.new()
    style.set_bg(Gtk::STATE_NORMAL, 0xFF ** 2, 0xFF ** 2, 0xFF ** 2)
    style end
end

# Module.new do

#   @tabclass = Class.new(Addon.gen_tabclass){
#     def initialize(name, service, options = {})
#       @page = 1
#       options[:header] = Gtk::VBox.new(false, 0)
#       super(name, service, options) end

#     def suffix
#       'のプロフィール' end

#     def user
#       @options[:user] end

#     def on_create
#       @appear_event = Plugin::create(:profile).add_event(:appear){ |res|
#         unless timeline.destroyed?
#           msgs = res.select{ |msg| msg[:user][:id] == user[:id] }
#           timeline.add(msgs) if not msgs.empty? end }
#       @service.user_timeline(user_id: user[:id], include_rts: 1, count: 20).next{ |tl|
#         timeline.add(tl) if not(timeline.destroyed?) and tl
#       }.terminate("@#{user[:idname]} の最近のつぶやきが取得できませんでした。見るなってことですかね")
#       @service.call_api(:list_user_followers, user_id: user[:id], filter_to_owned_lists: 1){ |res|
#         if not(@notebook.destroyed?) and res
#           followed_list_ids = res.map{|list| list['id'].to_i}
#           locked = {}
#           @list = Gtk::ListList.new{ |iter|
#             if not locked[iter[1]]
#               locked[iter[1]] = true
#               flag = iter[0] # = !iter[0]
#               list = iter[2]
#               @service.__send__(flag ? :delete_list_member : :add_list_member,
#                                 :list_id => list['id'],
#                                 :user_id => user[:id]).next{ |result|
#                 iter[0] = !flag if not(@list.destroyed?)
#                 locked[iter[1]] = false
#                 if flag
#                   list.remove_member(user)
#                   Plugin.call(:list_member_removed, @service, user, list, @service.user_obj)
#                 else
#                   list.add_member(user)
#                   Plugin.call(:list_member_added, @service, user, list, @service.user_obj) end
#               }.terminate{ |e|
#                 locked[iter[1]] = false
#                 "@#{user[:idname]} をリスト #{iter[2]['name']} に追加できませんでした" } end }
#           @list.set_auto_get(true){ |list|
#             followed_list_ids.include?(list['id'].to_i) }
#           @notebook.append_page(@list.show_all,
#                                 Gtk::WebIcon.new(MUI::Skin.get("list.png"), 16, 16).show_all) end }
#       header.closeup(profile).show_all
#       super
#       focus end

#     def on_remove
#       super
#       Plugin::create(:profile).detach(:appear, @appear_event) end

#     private

#     def gen_main
#       @timeline = Gtk::TimeLine.new
#       @notebook = Gtk::Notebook.new.set_tab_pos(Gtk::POS_TOP).set_tab_border(0)
#       @notebook.append_page(@timeline,
#                             Gtk::WebIcon.new(MUI::Skin.get("timeline.png"), 16, 16).show_all)
#       Plugin.filtering(:profile_tab, @notebook, user)
#       @header = (@options[:header] or Gtk::HBox.new)
#       Gtk::VBox.new(false, 0).closeup(@header).add(@notebook) end

#     def background_color
#       style = Gtk::Style.new()
#       style.set_bg(Gtk::STATE_NORMAL, 0xFF ** 2, 0xFF ** 2, 0xFF ** 2)
#       style end

#     def relation
#       relationbox = Gtk::VBox.new(false, 0)
#       if user[:idname] == @service.user
#         relationbox.add(Gtk::Label.new('それはあなたです！'))
#       else
#         @service.friendship(target_id: user[:id], source_id: @service.user_obj[:id]).next{ |rel|
#           if rel
#             unless(relationbox.destroyed?)
#               relationbox.closeup(Gtk::Label.new("#{user[:idname]}はあなたをフォローしていま" +
#                                                  if rel[:followed_by] then 'す' else 'せん' end)).
#                 closeup(followbutton(rel[:user], rel[:following])).
#                 closeup(mutebutton(rel[:user])).show_all end end }.terminate
#       end
#       relationbox end

#     def profile
#       eventbox = Gtk::EventBox.new
#       eventbox.signal_connect('visibility-notify-event'){
#         eventbox.style = background_color
#         false }
#       eventbox.add(Gtk::VBox.new(false, 0).
#                    closeup(toolbar).
#                    add(Gtk::HBox.new(false, 16).
#                        closeup(Gtk::WebIcon.new(user[:profile_image_url]).top).
#                        add(Gtk::VBox.new(false, 0).add(main(eventbox)).add(relation)))) end

#     def followbutton(user, following)
#       btn = nil
#       changer = lambda{ |new, widget|
#         if new === nil
#           following
#         elsif new != following
#           widget.sensitive = false
#           @service.method(new ? :follow : :unfollow).call(user){ |event, msg|
#             case event
#             when :exit
#               Plugin.call(new ? :followings_created : :followings_destroy, @service, [user])
#               following = new
#               Delayer.new{
#                 unless widget.destroyed?
#                   widget.sensitive = true end } end } end }
#       btn = Mtk::boolean(changer, 'フォロー') end

#     def mutebutton(user)
#       changer = lambda{ |new, widget|
#         if new === nil
#           UserConfig[:muted_users] and UserConfig[:muted_users].include?(user.idname)
#         elsif new
#           add_muted_user(user)
#         else
#           remove_muted_user(user)
#         end
#       }
#       btn = Mtk::boolean(changer, 'ミュート')
#     end

#     def add_muted_user(user)
#       type_strict user => User
#       atomic{
#         muted = (UserConfig[:muted_users] ||= []).melt
#         muted << user.idname
#         UserConfig[:muted_users] = muted } end

#     def remove_muted_user(user)
#       type_strict user => User
#       atomic{
#         muted = (UserConfig[:muted_users] ||= []).melt
#         muted.delete(user.idname)
#         UserConfig[:muted_users] = muted } end

#     def toolbar
#       container = Gtk::HBox.new(false, 0)
#       close = Gtk::Button.new.add(Gtk::WebIcon.new(MUI::Skin.get('close.png'), 16, 16))
#       close.signal_connect('clicked'){
#         remove }
#       container.closeup(close) end

#     def main(window_parent)
#       ago = (Time.now - (user[:created] or 1)).to_i / (60 * 60 * 24)
#       tags = []
#       text = "#{user[:idname]} #{user[:name]}\n"
#       append = lambda{ |title, value|
#         tags << ['_caption_style', text.size, title.size]
#         text << "#{title} #{value}" }
#       append.call "location", "#{user[:location]}\n" if user[:location]
#       append.call  "web", "#{user[:url]}\n" if user[:url]
#       append.call "bio", "#{user[:detail]}\n\n" if user[:detail]
#       append.call "フォロー", "#{user[:friends_count]} / "
#       append.call "フォロワー", "#{user[:followers_count]} / #{user[:statuses_count]}Tweets " +
#         "(#{if ago == 0 then user[:statuses_count] else (user[:statuses_count].to_f / ago).round_at(2) end}/day)\n"
#       append.call "since", "#{user[:created].strftime('%Y/%m/%d %H:%M:%S')}" if user[:created]
#       body = Gtk::IntelligentTextview.new(text)
#       body.buffer.create_tag('_caption_style',
#                              'foreground_gdk' => Gdk::Color.new(0, 0x33 ** 2, 0x66 ** 2),
#                              'weight' => Pango::FontDescription::WEIGHT_BOLD)
#       tags << [tag_user_id_link(body), 0, user[:idname].size]
#       tags.each{ |token|
#         body.buffer.apply_tag(token[0], *body.buffer.get_range(*token[1..2])) }
#       body.get_background = lambda{ background_color }
#       body end

#     private

#     def tag_user_id_link(body)
#       tag = body.buffer.create_tag('_user_id_link',
#                                    'foreground' => 'blue',
#                                    "underline" => Pango::UNDERLINE_SINGLE)
#       tag.signal_connect('event'){ |this, textview, event, iter|
#         result = false
#         if(event.is_a?(Gdk::EventButton)) and
#             (event.event_type == Gdk::Event::BUTTON_RELEASE) and
#             not(textview.buffer.selection_bounds[2])
#           if (event.button == 1)
#             Gtk::openurl('http://twitter.com/#!/'+user[:idname]) end
#         elsif(event.is_a?(Gdk::EventMotion))
#           body.set_cursor(textview, Gdk::Cursor::HAND2) end
#         result }
#       tag end }

#   def self.boot
#     plugin = Plugin::create(:profile)
#     plugin.add_event(:show_profile){ |service, user|
#       makescreen(user, service) }
#     plugin.add_event(:boot){ |service|
#       set_contextmenu(plugin, service)
#       Message::Entity.addlinkrule(:user_mentions, /(?:@|＠|〄|☯|⑨|♨|(?:\W|^)D )[a-zA-Z0-9_]+/){ |segment|
#         idname = segment[:url].match(/^(?:@|＠|〄|☯|⑨|♨|(?:\W|^)D )?(.+)$/)[1]
#         user = User.findbyidname(idname)
#         if user
#           makescreen(user, service)
#         else
#           Thread.new{
#             user = service.scan(:user_show,
#                                 :no_auto_since_id => false,
#                                 :screen_name => idname)
#             Delayer.new{ makescreen(user, service) } if user } end } }
#     plugin.add_event_filter(:show_filter){ |messages|
#       muted_users = UserConfig[:muted_users]
#       if muted_users && !muted_users.empty?
#         [messages.select{ |m| !muted_users.include?(m.idname) && (m.receive_user_screen_names & muted_users).empty? }]
#       else
#         [messages] end } end

#   private

#   def self.set_contextmenu(plugin, service)

#     plugin.add_event_filter(:command){ |menu|
#       menu[:show_profile] = {
#         :slug => :show_profile,
#         :name => 'ユーザについて',
#         :show_face => lambda{ |m|
#           u = if(m.message[:retweet])
#                 m.message[:retweet].user
#               else
#                 m.message.user end
#           "#{u[:idname]}(#{u[:name]})について".gsub(/_/, '__') },
#         :condition => lambda{ |m| m.message.repliable? },
#         :exec => lambda{ |m|
#           user = if(m.is_a? User)
#                    m
#                  elsif(m.message[:retweet])
#                    m.message[:retweet].user
#                  else
#                    m.message.user end
#           makescreen(user, service) },
#         :visible => true,
#         :role => :message }
#       [menu]
#     }

#     return

#     plugin.add_event_filter(:contextmenu){ |menu|
#       menu << [lambda{ |m, w|
#                  if(nil == m and nil == w)
#                    'ユーザについて'
#                  else
#                  u = if(m.message[:retweet])
#                        m.message[:retweet].user
#                      else
#                        m.message.user end
#                  "#{u[:idname]}(#{u[:name]})について".gsub(/_/, '__') end },
#                lambda{ |m, w| m.message.repliable? },
#                lambda{ |m, w|
#                  user = if(m.message[:retweet]) then m.message[:retweet].user else m.message.user end
#                  makescreen(user, service) } ]
#       [menu] }
#   end

#   def self.makescreen(user, service)
#     if user[:exact]
#       @tabclass.new("#{user[:idname]}(#{user[:name]})", service,
#                     :user => user,
#                     :icon => user[:profile_image_url])
#     else
#       service.user_show(id: user[:id], cache: :keep).next{ |new_user|
#         raise "inexact user data" if not new_user[:exact]
#         makescreen(new_user, service) if new_user.is_a? User }.terminate("@#{user[:idname]}の情報が取得できませんでした")
#     end end

#   boot
# end
# ~> /home/toshi/Documents/hobby/scripts/mikutter.git/core/plugin/profile/profilenotebook.rb:3:in `<top (required)>': uninitialized constant UserConfig (NameError)
# ~> 	from /usr/lib/ruby/1.9.1/rubygems/custom_require.rb:36:in `require'
# ~> 	from /usr/lib/ruby/1.9.1/rubygems/custom_require.rb:36:in `require'
# ~> 	from -:4:in `<main>'
