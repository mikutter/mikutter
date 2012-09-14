# -*- coding: utf-8 -*-

# RubyGnome2を用いてUIを表示するプラグイン

require "gtk2"
require File.expand_path File.join(File.dirname(__FILE__), 'mikutter_window')

Plugin.create :gtk do
  @windows_by_slug = {}                  # slug => Gtk::MikutterWindow
  @panes_by_slug = {}                    # slug => Gtk::NoteBook
  @tabs_by_slug = {}                     # slug => Gtk::EventBox
  @timelines_by_slug = {}                # slug => Gtk::TimeLine
  @tabchildwidget_by_slug = {}           # slug => Gtk::TabChildWidget
  @postboxes_by_slug = {}                # slug => Gtk::Postbox
  @tabs_promise = {}                     # slug => Deferred

  TABPOS = [Gtk::POS_TOP, Gtk::POS_BOTTOM, Gtk::POS_LEFT, Gtk::POS_RIGHT]

  # ウィンドウ作成。
  # PostBoxとか複数のペインを持つための処理が入るので、Gtk::MikutterWindowクラスを新設してそれを使う
  on_window_created do |i_window|
    notice "create window #{i_window.slug.inspect}"
    window = Gtk::MikutterWindow.new
    @windows_by_slug[i_window.slug] = window
    window.title = i_window.name
    window.set_size_request(240, 240)
    geometry = get_window_geometry(i_window.slug)
    window.set_default_size(*geometry[:size])
    window.move(*geometry[:position])
    window.signal_connect("destroy"){
      Delayer.freeze
      window.destroy
      Gtk::Object.main_quit
      # Gtk.main_quit
      false }
    window.ssc(:focus_in_event) {
      i_window.active!
      false
    }
    window.ssc('key_press_event'){ |widget, event|
      Plugin::GUI.keypress(Gtk::keyname([event.keyval ,event.state]), i_window) }
    window.show_all
  end

  # ペイン作成。
  # ペインはGtk::NoteBook
  on_pane_created do |i_pane|
    notice "create pane #{i_pane.slug.inspect}"
    pane = Gtk::Notebook.new.set_tab_pos(TABPOS[UserConfig[:tab_position]]).set_tab_border(0).set_group_id(0).set_scrollable(true)
    @panes_by_slug[i_pane.slug] = pane
    tab_position_hook_id = UserConfig.connect(:tab_position){ |key, val, before_val, id|
      notice "change tab pos to #{TABPOS[val]}"
      pane.set_tab_pos(TABPOS[val]) }
    pane.signal_connect('page-reordered'){
      # UserConfig[:tab_order] = books_labels
      false }
    pane.signal_connect('page-added'){ |this, widget|
      # notice "#{args.inspect}"
      notice "gtk:page-added: "
      i_widget = find_slug_by_gtkwidget(widget)
      next false unless i_widget
      i_tab = i_widget.parent
      next false unless i_tab and i_tab.parent != i_pane
      i_pane << i_tab
      false }
    # 子が無くなった時 : このpaneを削除
    pane.signal_connect('page-removed'){
      Delayer.new{
        unless pane.destroyed?
          if pane.children.empty? and pane.parent
            UserConfig.disconnect(tab_position_hook_id)
            pane.parent.remove(pane) end
          # UserConfig[:tab_order] = books_labels
        end }
      false }
    pane.ssc('key_press_event'){ |widget, event|
      Plugin::GUI.keypress(Gtk::keyname([event.keyval ,event.state]), i_pane) }
    pane.show_all
  end

  # タブ作成。
  # タブには実体が無いので、タブのアイコンのところをGtk::EventBoxにしておいて、それを実体ということにしておく
  on_tab_created do |i_tab|
    notice "create tab #{i_tab.slug.inspect}"
    tab = Gtk::EventBox.new.tooltip(i_tab.name)
    @tabs_by_slug[i_tab.slug] = tab
    tab_update_icon(i_tab)
    tab.ssc(:focus_in_event) {
      i_tab.active!
      false
    }
    tab.ssc('key_press_event'){ |widget, event|
      Plugin::GUI.keypress(Gtk::keyname([event.keyval ,event.state]), i_tab) }
    tab.ssc(:button_press_event) { |this, e|
      notice "tab press: pass"
      if e.button == 3
        Plugin::GUI::Command.menu_pop(i_tab)
      end
    }
    tab.show_all
    if @tabs_promise[i_tab.slug]
      @tabs_promise[i_tab.slug].call(tab)
      @tabs_promise.delete(i_tab.slug) end end

  # タイムライン作成。
  # Gtk::TimeLine
  on_timeline_created do |i_timeline|
    notice "create timeline #{i_timeline.slug.inspect}"
    timeline = Gtk::TimeLine.new
    @timelines_by_slug[i_timeline.slug] = timeline
    timeline.tl.ssc(:focus_in_event) {
      i_timeline.active!
      false }
    timeline.ssc('key_press_event'){ |widget, event|
      Plugin::GUI.keypress(Gtk::keyname([event.keyval ,event.state]), i_timeline) }
    timeline.show_all
  end

  on_gui_pane_join_window do |i_pane, i_window|
    puts "gui_pane_join_window #{i_pane.slug.inspect}, #{i_window.slug.inspect}"
    window = widgetof(i_window)
    pane = widgetof(i_pane)
    if pane.parent
      if pane.parent != window.panes
        notice "pane parent already exists. removing"
        pane.parent.remove(pane)
        notice "packing"
        window.panes.pack_end(pane, false).show_all
        notice "done" end
    else
      notice "pane doesn't have a parent"
      window.panes.pack_end(pane, false).show_all
    end
  end

  on_gui_tab_join_pane do |i_tab, i_pane|
    notice "gui_tab_join_pane(#{i_tab}, #{i_pane})"
    i_widget = i_tab.children.first
    notice "#{i_tab} children #{i_tab.children}"
    next if not i_widget
    widget = widgetof(i_widget)
    notice "widget: #{widget}"
    next if not widget
    tab = widgetof(i_tab)
    pane = widgetof(i_pane)
    old_pane = widget.parent
    notice "pane: #{pane}, old_pane: #{old_pane}"
    if pane and old_pane and pane != old_pane
      notice "#{widget} removes by #{old_pane}"
      old_pane.remove_page(old_pane.page_num(widget))
      if tab.parent
        notice "#{tab} removes by #{tab.parent}"
        tab.parent.remove(tab) end
      notice "#{widget} pack to #{tab}"
      widget_join_tab(i_tab, widget) end
  end

  on_gui_timeline_join_tab do |i_timeline, i_tab|
    i_pane = i_tab.parent
    pane = widgetof(i_pane)
    timeline = widgetof(i_timeline)
    index = where_should_insert_it(i_tab.slug, i_pane.children.map(&:slug), [:home_timeline, :mentions])
    pane.insert_page_menu(index, timeline, widgetof(i_tab))
    pane.set_tab_reorderable(timeline, true).set_tab_detachable(timeline, true)
  end

  on_gui_timeline_add_messages do |i_timeline, messages|
    widgetof(i_timeline).add(messages)
  end

  on_gui_postbox_join_widget do |i_postbox|
    notice "create postbox #{i_postbox.slug.inspect}"
    postbox = @postboxes_by_slug[i_postbox.slug] = widgetof(i_postbox.parent).add_postbox(i_postbox)
    postbox.post.ssc(:focus_in_event) {
      i_postbox.active!
      false }
    postbox.post.ssc('key_press_event'){ |widget, event|
      Plugin::GUI.keypress(Gtk::keyname([event.keyval ,event.state]), i_postbox) }
  end

  on_gui_tab_change_icon do |i_tab|
    tab_update_icon(i_tab) end

  on_gui_contextmenu do |event, contextmenu|
    Gtk::ContextMenu.new(*contextmenu).popup(widgetof(event.widget), event)
  end

  filter_gui_timeline_selected_messages do |i_timeline, messages|
    [i_timeline, messages + widgetof(i_timeline).get_active_messages] end

  def tab_update_icon(i_tab)
    type_strict i_tab => Plugin::GUI::Tab
    tab = widgetof(i_tab)
    tab.remove(tab.child) if tab.child
    if i_tab.icon.is_a?(String)
      tab.add(Gtk::WebIcon.new(i_tab.icon, 24, 24).show)
    else
      tab.add(Gtk::Label.new(i_tab.name).show) end
    self end

  def get_window_geometry(slug)
    type_strict slug => Symbol
    geo = at(:windows_geometry, {})
    if geo[slug]
      geo[slug]
    else
      size = [Gdk.screen_width/3, Gdk.screen_height*4/5]
      { size: size,
        position: [Gdk.screen_width - size[0], Gdk.screen_height/2 - size[1]/2] } end end

  # _cuscadable_ に対応するGtkオブジェクトを返す
  # ==== Args
  # [cuscadable] ウィンドウ、ペイン、タブ、タイムライン等
  # ==== Return
  # 対応するGtkオブジェクト
  def widgetof(cuscadable)
    type_strict cuscadable => :slug
    collection = if cuscadable.is_a? Plugin::GUI::Window
                   @windows_by_slug
                 elsif cuscadable.is_a? Plugin::GUI::Pane
                   @panes_by_slug
                 elsif cuscadable.is_a? Plugin::GUI::Tab
                   @tabs_by_slug
                 elsif cuscadable.is_a? Plugin::GUI::Timeline
                   @timelines_by_slug
                 elsif cuscadable.is_a? Plugin::GUI::TabChildWidget
                   @tabchildwidget_by_slug
                 elsif cuscadable.is_a? Plugin::GUI::Postbox
                   @postboxes_by_slug end
    collection[cuscadable.slug]
  end

  # Gtkオブジェクト _widget_ に対応するウィジェットのオブジェクトを返す
  # ==== Args
  # [widget] Gtkウィジェット
  # ==== Return
  # _widget_ に対応するウィジェットオブジェクトまたは偽
  def find_slug_by_gtkwidget(widget)
    type_strict widget => Gtk::Widget
    [
     [@windows_by_slug, Plugin::GUI::Window],
     [@panes_by_slug, Plugin::GUI::Pane],
     [@tabs_by_slug, Plugin::GUI::Tab],
     [@timelines_by_slug, Plugin::GUI::Timeline],
     [@tabchildwidget_by_slug, Plugin::GUI::TabChildWidget],
     [@postboxes_by_slug, Plugin::GUI::Postbox] ].each{ |collection, klass|
      slug, node = *collection.find{ |slug, node|
        node == widget }
      if slug
        return klass.instance(slug) end }
    false end
end

