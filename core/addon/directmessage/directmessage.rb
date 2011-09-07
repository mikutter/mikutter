# -*- coding: utf-8 -*-

Plugin.create(:directmessage) do

  # user_id => [Direct Message...]
  @dm_store = Hash.new{|h, k|
    Plugin.call(:direct_message_add_user, k)
    h[k] = [] }
  @dm_lock = Mutex.new
  @counter = gen_counter

  onboot do
    @userlist = Gtk::UserList.new.show_all
    @userlist.double_clicked = lambda{ |user|
      Plugin.call(:show_profile, Post.primary_service, user) }
    Delayer.new{
      Plugin.call(:mui_tab_regist, @userlist, 'Direct Message', MUI::Skin.get("underconstruction.png"))
    }
  end

  onperiod do
    service = Post.primary_service
    if 0 == (@counter.call % UserConfig[:retrieve_interval_direct_messages])
      service.call_api(:direct_messages, :count => UserConfig[:retrieve_count_direct_messages]){ |dms|
        Plugin.call(:direct_messages, service, dms) } end end

  filter_direct_messages do |service, dms|
    result = []
    @dm_lock.synchronize do
      dms.sort_by{ |s| Time.parse(s[:created_at]) rescue Time.now }.each { |dm|
        if add_dm(dm, dm[:sender][:id].to_i) and add_dm(dm, dm[:recipient][:id].to_i)
          result << dm end } end
    [service, result] end

  on_direct_message_add_user do |user_id|
    user = User.findbyid(user_id)
    if user.is_a? User
      @userlist.add(user)
    end
  end

  filter_profile_tab do |notebook, user|
    notebook.append_page(dm_list_widget(user), Gtk::WebIcon.new(MUI::Skin.get("underconstruction.png"), 16, 16).show_all)
    [notebook, user]
  end

  def add_dm(dm, user_id)
    unless @dm_store[user_id].any?{ |stored| stored[:id] == dm[:id] }
      @dm_store[user_id] << dm end
  end

  def dm_list_widget(user)
    container = Gtk::HBox.new
    tl = DirectMessage.new
    tl.model.set_sort_column_id(DirectMessage::C_ID, Gtk::SORT_DESCENDING)

    scrollbar = Gtk::VScrollbar.new(tl.vadjustment)
    model = tl.model
    @dm_lock.synchronize do
      if @dm_store.has_key?(user[:id])
        @dm_store[user[:id]].each { |dm|
          iter = model.append
          iter[DirectMessage::C_ID] = dm[:id].to_i
          iter[DirectMessage::C_ICON] = Gtk::WebIcon.get_icon_pixbuf(dm[:sender][:profile_image_url], 16, 16)
          iter[DirectMessage::C_TEXT] = dm[:text]
          iter[DirectMessage::C_RAW] = dm } end end

    event = on_direct_messages do |service, dms|
      if not tl.destroyed?
        dms.each{ |dm|
          if user[:id].to_i == dm[:sender][:id].to_i or user[:id].to_i == dm[:recipient][:id].to_i
            iter = model.append
            iter[DirectMessage::C_ID] = dm[:id].to_i
            iter[DirectMessage::C_ICON] = Gtk::WebIcon.get_icon_pixbuf(dm[:sender][:profile_image_url], 16, 16)
            iter[DirectMessage::C_TEXT] = dm[:text]
            iter[DirectMessage::C_RAW] = dm end } end end

    tl.ssc(:scroll_event){ |this, e|
      case e.direction
      when Gdk::EventScroll::UP
        this.vadjustment.value -= this.vadjustment.step_increment
      when Gdk::EventScroll::DOWN
        this.vadjustment.value += this.vadjustment.step_increment end
      false }

    tl.ssc(:destroy){
      detach(:direct_message, event)
    }

    container.add(Gtk::HBox.new.add(tl).closeup(scrollbar))
    container
  end

  class DirectMessage < Gtk::CRUD
    C_ID = 2
    C_ICON = 0
    C_TEXT = 1
    C_RAW = 3

    def column_schemer
      [{:kind => :pixbuf, :type => Gdk::Pixbuf, :label => 'icon'},
       {:kind => :text, :type => String, :label => '本文'},
       {:type => Integer},
       {:type => Object},
      ].freeze
    end
  end

end
