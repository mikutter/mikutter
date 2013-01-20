# -*- coding: utf-8 -*-

# RubyGnome2を用いてUIを表示するプラグイン

require "gtk2"

miquire :mui,
'cell_renderer_message', 'coordinate_module', 'icon_over_button', 'inner_tl', 'markup_generator',
'miracle_painter', 'pseudo_message_widget', 'replyviewer', 'sub_parts_favorite', 'sub_parts_helper',
'sub_parts_retweet', 'sub_parts_voter', 'textselector', 'timeline', 'contextmenu', 'crud',
'extension', 'intelligent_textview', 'keyconfig', 'listlist', 'message_picker', 'mtk', 'postbox',
'pseudo_signal_handler', 'selectbox', 'timeline_utils', 'userlist', 'webicon'

require File.expand_path File.join(File.dirname(__FILE__), 'mikutter_window')
require File.expand_path File.join(File.dirname(__FILE__), 'tab_container')
require File.expand_path File.join(File.dirname(__FILE__), 'tab_toolbar')
require File.expand_path File.join(File.dirname(__FILE__), 'delayer')
require File.expand_path File.join(File.dirname(__FILE__), 'slug_dictionary')
require File.expand_path File.join(File.dirname(__FILE__), 'mainloop')

Plugin.create :gtk do
  @slug_dictionary = Plugin::Gtk::SlugDictionary.new # widget_type => {slug => Gtk}
  @tabs_promise = {}                     # slug => Deferred

  TABPOS = [Gtk::POS_TOP, Gtk::POS_BOTTOM, Gtk::POS_LEFT, Gtk::POS_RIGHT]

  # ウィンドウ作成。
  # PostBoxとか複数のペインを持つための処理が入るので、Gtk::MikutterWindowクラスを新設してそれを使う
  on_window_created do |i_window|
    notice "create window #{i_window.slug.inspect}"
    window = ::Gtk::MikutterWindow.new(i_window)
    @slug_dictionary.add(i_window, window)
    window.title = i_window.name
    window.set_size_request(240, 240)
    geometry = get_window_geometry(i_window.slug)
    window.set_default_size(*geometry[:size])
    window.move(*geometry[:position])
    window.ssc(:event){ |window, event|
      if event.is_a? Gdk::EventConfigure
        geometry = (UserConfig[:windows_geometry] || {}).melt
        size = window.window.geometry[2,2]
        position = window.position
        modified = false
        if defined?(geometry[i_window.slug]) and geometry[i_window.slug].is_a? Hash
          geometry[i_window.slug] = geometry[i_window.slug].melt
          if geometry[i_window.slug][:size] != size
            modified = geometry[i_window.slug][:size] = size end
          if geometry[i_window.slug][:position] != position
            modified = geometry[i_window.slug][:position] = position end
        else
          modified = geometry[i_window.slug] = {
            size: size,
            position: position } end
        if modified
          UserConfig[:windows_geometry] = geometry end end
      false }
    window.ssc("destroy"){
      Delayer.freeze
      window.destroy
      ::Gtk::Object.main_quit
      # Gtk.main_quit
      false }
    window.ssc(:focus_in_event) {
      i_window.active!(true, true)
      false
    }
    window.ssc('key_press_event'){ |widget, event|
      Plugin::GUI.keypress(::Gtk::keyname([event.keyval ,event.state]), i_window) }
    window.show_all
  end

  on_gui_window_change_icon do |i_window, icon|
    window = widgetof(i_window)
    if window
      window.icon = Gdk::Pixbuf.new(icon, 256, 256) end end

  # ペイン作成。
  # ペインはGtk::NoteBook
  on_pane_created do |i_pane|
    pane = create_pane(i_pane)
    pane.set_tab_border(0).set_group_id(0).set_scrollable(true)
    pane.set_tab_pos(TABPOS[UserConfig[:tab_position]])
    tab_position_hook_id = UserConfig.connect(:tab_position){ |key, val, before_val, id|
      notice "change tab pos to #{TABPOS[val]}"
      pane.set_tab_pos(TABPOS[val]) unless pane.destroyed? }
    pane.ssc(:page_reordered){ |this, tabcontainer, index|
      notice "on_pane_created: page_reordered: #{i_pane.inspect}"
      window_order_save_request(i_pane.parent) if i_pane.parent
      i_tab = tabcontainer.i_tab
      notice "tabcontainer #{tabcontainer} => #{i_tab.inspect}"
      if i_tab
        i_pane.reorder_child(i_tab, index) end
      false }
    pane.ssc(:switch_page){ |this, page, pagenum|
      if pagenum == pane.page
        i_pane.set_active_child(pane.get_nth_page(pagenum).i_tab, true)
      else
        notice "switch_page: pagenum(#{pagenum}) != pane.page(#{pane.page})" end }
    pane.signal_connect(:page_added){ |this, tabcontainer, index|
      type_strict tabcontainer => ::Gtk::TabContainer
      notice "on_pane_created: page_added: #{i_pane.inspect}"
      window_order_save_request(i_pane.parent) if i_pane.parent
      i_tab = tabcontainer.i_tab
      next false if i_tab.parent == i_pane
      notice "on_pane_created: reparent"
      i_pane.add_child(i_tab, index)
      false }
    # 子が無くなった時 : このpaneを削除
    pane.signal_connect(:page_removed){
      notice "on_pane_created: page_removed: #{i_pane.inspect}"
      if not(pane.destroyed?) and pane.children.empty? and pane.parent
        pane.parent.remove(pane)
        UserConfig.disconnect(tab_position_hook_id)
        pane_order_delete(i_pane)
        i_pane.destroy end
      false }
  end

  # タブ作成。
  # タブには実体が無いので、タブのアイコンのところをGtk::EventBoxにしておいて、それを実体ということにしておく
  on_tab_created do |i_tab|
    tab = create_tab(i_tab)
    if @tabs_promise[i_tab.slug]
      @tabs_promise[i_tab.slug].call(tab)
      @tabs_promise.delete(i_tab.slug) end end

  on_profile_created do |i_profile|
    create_pane(i_profile) end

  on_profiletab_created do |i_profiletab|
    create_tab(i_profiletab) end

  # タブを作成する
  # ==== Args
  # [i_tab] タブ
  # ==== Return
  # Tab(Gtk::EventBox)
  def create_tab(i_tab)
    notice "create tab #{i_tab.slug.inspect}"
    tab = ::Gtk::EventBox.new.tooltip(i_tab.name)
    @slug_dictionary.add(i_tab, tab)
    tab_update_icon(i_tab)
    tab.ssc(:focus_in_event) {
      i_tab.active!(true, true)
      false
    }
    tab.ssc(:key_press_event){ |widget, event|
      Plugin::GUI.keypress(::Gtk::keyname([event.keyval ,event.state]), i_tab) }
    tab.ssc(:button_press_event) { |this, e|
      if e.button == 3
        Plugin::GUI::Command.menu_pop(i_tab) end
      false }
    tab.ssc(:destroy){
      i_tab.destroy
      false }
    tab.show_all end

  on_tab_toolbar_created do |i_tab_toolbar|
    notice "create tab toolbar #{i_tab_toolbar.inspect}"
    tab_toolbar = ::Gtk::TabToolbar.new(i_tab_toolbar).show_all
    @slug_dictionary.add(i_tab_toolbar, tab_toolbar)
  end

  on_gui_tab_toolbar_join_tab do |i_tab_toolbar, i_tab|
    widget = widgetof(i_tab_toolbar)
    widget_join_tab(i_tab, widget) if widget
  end

  # タイムライン作成。
  # Gtk::TimeLine
  on_timeline_created do |i_timeline|
    notice "create timeline #{i_timeline.slug.inspect}"
    timeline = ::Gtk::TimeLine.new(i_timeline)
    @slug_dictionary.add(i_timeline, timeline)
    handler = {
      key_press_event: timeline_key_press_event(i_timeline),
      focus_in_event: timeline_focus_in_event(i_timeline),
      destroy: lambda{ |this| timeline_hook_events(timeline, handler) } }
    timeline_hook_events(timeline, handler)
    timeline.ssc(:destroy){
      i_timeline.destroy
      false }
    timeline.show_all
  end

  # Gtk::TimeLine::InnerTL にたいして、イベントのリスナを登録する。
  # ==== Args
  # [gtk_timeline] 対象となる Gtk::TimeLine のインスタンス
  def timeline_hook_events(gtk_timeline, handler)
    handler.each{ |event_name, callback|
      gtk_timeline.tl.ssc(event_name, gtk_timeline, &callback) } end

  # Timelineウィジェットのfocus_in_eventのコールバックを返す
  # ==== Args
  # [i_timeline] タイムラインのインターフェイス
  # ==== Return
  # コールバック関数
  def timeline_focus_in_event(i_timeline)
    lambda { |this, event|
      if this.focus?
        i_timeline.active!(true, true)
      else
        notice "timeline_created: focus_in_event: event receive but not has focus #{i_timeline}" end
      false } end

  # Timelineウィジェットのkey_press_eventのコールバックを返す
  # ==== Args
  # [i_timeline] タイムラインのインターフェイス
  # ==== Return
  # コールバック関数
  def timeline_key_press_event(i_timeline)
    lambda { |widget, event|
      Plugin::GUI.keypress(::Gtk::keyname([event.keyval ,event.state]), i_timeline) } end

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
    old_pane = widget.get_ancestor(::Gtk::Notebook)
    notice "pane: #{pane}, old_pane: #{old_pane}"
    if tab and pane and old_pane and pane != old_pane
      notice "#{widget} removes by #{old_pane}"
      if tab.parent
        page_num = tab.parent.get_tab_pos_by_tab(tab)
        if page_num
          tab.parent.remove_page(page_num)
        else
          raise Plugin::Gtk::GtkError, "#{tab} not found in #{tab.parent}" end end
      notice "#{widget} pack to #{tab}"
      i_tab.children.each{ |i_child|
        w_child = widgetof(i_child)
        w_child.parent.remove(w_child)
        widget_join_tab(i_tab, w_child) }
      tab.show_all end
    window_order_save_request(i_pane.parent) if i_pane.parent
  end

  on_gui_timeline_join_tab do |i_timeline, i_tab|
    widget = widgetof(i_timeline)
    widget_join_tab(i_tab, widget) if widget end

  on_gui_profile_join_tab do |i_profile, i_tab|
    widget = widgetof(i_profile)
    widget_join_tab(i_tab, widget) if widget end

  on_gui_timeline_add_messages do |i_timeline, messages|
    gtk_timeline = widgetof(i_timeline)
    gtk_timeline.add(messages) if gtk_timeline and not gtk_timeline.destroyed? end

  on_gui_postbox_join_widget do |i_postbox|
    notice "create postbox #{i_postbox.slug.inspect}"
    type_strict i_postbox => Plugin::GUI::Postbox
    i_postbox_parent = i_postbox.parent
    next if not i_postbox_parent
    postbox_parent = widgetof(i_postbox_parent)
    next if not postbox_parent
    postbox = @slug_dictionary.add(i_postbox, postbox_parent.add_postbox(i_postbox))
    postbox.post.ssc(:focus_in_event) {
      i_postbox.active!(true, true)
      false }
    postbox.post.ssc('key_press_event'){ |widget, event|
      Plugin::GUI.keypress(::Gtk::keyname([event.keyval ,event.state]), i_postbox) }
    postbox.post.ssc(:destroy){
      i_postbox.destroy
      false }
  end

  on_gui_tab_change_icon do |i_tab|
    tab_update_icon(i_tab) end

  on_gui_contextmenu do |event, contextmenu|
    widget = widgetof(event.widget)
    if widget
      ::Gtk::ContextMenu.new(*contextmenu).popup(widget, event) end end

  on_gui_timeline_clear do |i_timeline|
    timeline = widgetof(i_timeline)
    if timeline
      timeline.clear end end

  on_gui_timeline_scroll_to_top do |i_timeline|
    notice "called"
    timeline = widgetof(i_timeline)
    if timeline
      timeline.set_cursor_to_display_top end end

  on_gui_timeline_move_cursor_to do |i_timeline, message|
    tl = widgetof(i_timeline)
    if tl
      path, column = tl.cursor
      notice "path: #{path}, column: #{column}"
      if path and column
        case message
        when :prev
          path.prev!
          tl.set_cursor(path, column, false)
        when :next
          path.next!
          tl.set_cursor(path, column, false)
        else
          if message.is_a? Integer
            path, = *tl.get_path(0, message)
              tl.set_cursor(path, column, false) if path end end end end end

  on_gui_postbox_post do |i_postbox|
    postbox = widgetof(i_postbox)
    if postbox
      postbox.post_it end end

  # i_widget.destroyされた時に呼ばれる。
  # 必要ならば、ウィジェットの実体もあわせて削除する。
  on_gui_destroy do |i_widget|
    widget = widgetof(i_widget)
    if widget and not widget.destroyed?
      if i_widget.is_a?(Plugin::GUI::Tab) and i_widget.parent
        pane = widgetof(i_widget.parent)
        if pane
          pane.n_pages.times{ |pagenum|
            if widget == pane.get_tab_label(pane.get_nth_page(pagenum))
              pane.remove_page(pagenum)
              break end } end
      else
        widget.parent.remove(widget) if widget.parent
        widget.destroy end end end

  # 互換性のため
  on_mui_tab_regist do |container, name, icon|
    slug = name.to_sym
    i_tab = Plugin::GUI::Tab.instance(slug, name)
    i_tab.set_icon(icon).expand
    i_container = Plugin::GUI::TabChildWidget.instance
    @slug_dictionary.add(i_container, container)
    i_tab << i_container
    @tabs_promise[i_tab.slug] = (@tabs_promise[i_tab.slug] || Deferred.new).next{ |tab|
      widget_join_tab(i_tab, container.show_all) } end

  # Gtkオブジェクトをタブに入れる
  on_gui_nativewidget_join_tab do |i_tab, i_container, container|
    notice "nativewidget: #{container} => #{i_tab}"
    @slug_dictionary.add(i_container, container)
    widget_join_tab(i_tab, container.show_all) end

  on_gui_nativewidget_join_profiletab do |i_profiletab, i_container, container|
    notice "nativewidget: #{container} => #{i_profiletab}"
    @slug_dictionary.add(i_container, container)
    widget_join_tab(i_profiletab, container.show_all) end

  on_gui_window_rewindstatus do |i_window, text, expire|
    statusbar = @slug_dictionary.get(Plugin::GUI::Window, :default).statusbar
    cid = statusbar.get_context_id("system")
    mid = statusbar.push(cid, text)
    notice "rewind statusbar to #{text}, #{expire.inspect}, #{cid}"
    if expire != 0
      Reserver.new(expire){
        if not statusbar.destroyed?
          statusbar.remove(cid, mid) end } end end

  on_gui_child_activated do |i_parent, i_child, by_toolkit|
    type_strict i_parent => Plugin::GUI::HierarchyParent, i_child => Plugin::GUI::HierarchyChild
    if by_toolkit
      notice "activate by toolkit. ignore."
    else
      if i_child.is_a?(Plugin::GUI::TabLike)
        i_pane = i_parent
        i_tab = i_child
        notice "gui_child_activated: tab active #{i_pane} => #{i_tab}"
        pane = widgetof(i_pane)
        tab = widgetof(i_tab)
        if pane and tab
          pagenum = pane.get_tab_pos_by_tab(tab)
          pane.page = pagenum if pagenum and pane.page != pagenum end
      elsif i_parent.is_a?(Plugin::GUI::Window)
        i_term = i_child.respond_to?(:active_chain) ? i_child.active_chain.last : i_child
        if i_term
          window = widgetof(i_parent)
          widget = widgetof(i_term)
          if window and widget
            notice "ACTIVATE! #{window} => #{widget}"
            if widget.respond_to? :active
              widget.active
            else
              window.set_focus(widget) end end end end end end

  filter_gui_postbox_input_editable do |i_postbox, editable|
    postbox = widgetof(i_postbox)
    if postbox
      [i_postbox, postbox && postbox.post.editable?]
    else
      [i_postbox, editable] end end

  filter_gui_timeline_cursor_position do |i_timeline, y|
    timeline = widgetof(i_timeline)
    if timeline
      path, column = *timeline.cursor
      if path
        rect = timeline.get_cell_area(path, column)
        next [i_timeline, rect.y + (rect.height / 2).to_i] end
    end
    [i_timeline, y] end

  filter_gui_timeline_selected_messages do |i_timeline, messages|
    timeline = widgetof(i_timeline)
    if timeline
      [i_timeline, messages + timeline.get_active_messages]
    else
      [i_timeline, messages] end end

  filter_gui_timeline_selected_text do |i_timeline, message, text|
    timeline = widgetof(i_timeline)
    next [i_timeline, message, text] if not timeline
    record = timeline.get_record_by_message(message)
    next [i_timeline, message, text] if not record
    range = record.miracle_painter.textselector_range
    next [i_timeline, message, text] if not range
    [i_timeline, message, message.entity.to_s[range]]
  end

  filter_gui_destroyed do |i_widget|
    if i_widget.is_a? Plugin::GUI::Widget
      [!widgetof(i_widget)]
    else
      [i_widget] end end

  filter_gui_get_gtk_widget do |i_widget|
    [widgetof(i_widget)] end

  # タブ _tab_ に _widget_ を入れる
  # ==== Args
  # [i_tab] タブ
  # [widget] Gtkウィジェット
  def widget_join_tab(i_tab, widget)
    tab = widgetof(i_tab)
    return false if not tab
    i_pane = i_tab.parent
    return false if not i_pane
    pane = widgetof(i_pane)
    return false if not pane
    notice "widget_join_tab: #{widget} join #{i_tab}"
    container_index = pane.get_tab_pos_by_tab(tab)
    if container_index
      container = pane.get_nth_page(container_index)
      if container
        return container.pack_start(widget, i_tab.pack_rule[container.children.size]) end end
    if tab.parent
      raise Plugin::Gtk::GtkError, "Gtk Widget #{tab.inspect} of Tab(#{i_tab.slug.inspect}) has parent Gtk Widget #{tab.parent.inspect}" end
    container = ::Gtk::TabContainer.new(i_tab).show_all
    container.ssc(:key_press_event){ |w, event|
      Plugin::GUI.keypress(::Gtk::keyname([event.keyval ,event.state]), i_tab) }
    container.pack_start(widget, i_tab.pack_rule[container.children.size])
    pane.insert_page_menu(where_should_insert_it(i_tab, pane.children.map(&:i_tab), i_pane.children), container, tab)
    pane.set_tab_reorderable(container, true).set_tab_detachable(container, true)
    true end

  def tab_update_icon(i_tab)
    type_strict i_tab => Plugin::GUI::TabLike
    tab = widgetof(i_tab)
    if tab
      tab.remove(tab.child) if tab.child
      if i_tab.icon.is_a?(String)
        tab.add(::Gtk::WebIcon.new(i_tab.icon, 24, 24).show)
      else
        tab.add(::Gtk::Label.new(i_tab.name).show) end end
    self end

  def get_window_geometry(slug)
    type_strict slug => Symbol
    geo = UserConfig[:windows_geometry]
    if defined? geo[slug]
      geo[slug]
    else
      size = [Gdk.screen_width/3, Gdk.screen_height*4/5]
      { size: size,
        position: [Gdk.screen_width - size[0], Gdk.screen_height/2 - size[1]/2] } end end

  # ペインを作成
  # ==== Args
  # [i_pane] ペイン
  # ==== Return
  # ペイン(Gtk::Notebook)
  def create_pane(i_pane)
    notice "create pane #{i_pane.slug.inspect}"
    pane = ::Gtk::Notebook.new
    @slug_dictionary.add(i_pane, pane)
    pane.ssc('key_press_event'){ |widget, event|
      Plugin::GUI.keypress(::Gtk::keyname([event.keyval ,event.state]), i_pane) }
    pane.ssc(:destroy){
      i_pane.destroy if i_pane.destroyed?
      false }
    pane.show_all end

  # ウィンドウ内のペイン、タブの現在の順序を設定に保存する
  # ==== Args
  # [i_window] ウィンドウ
  def window_order_save_request(i_window)
    notice "window_order_save_request: #{i_window.inspect}"
    type_strict i_window => Plugin::GUI::Window
    Delayer.new do
      panes_order = {}
      i_window.children.each{ |i_pane|
        if i_pane.is_a? Plugin::GUI::Pane
          tab_order = []
          pane = widgetof(i_pane)
          if pane
            pane.n_pages.times{ |page_num|
              i_widget = find_implement_widget_by_gtkwidget(pane.get_tab_label(pane.get_nth_page(page_num)))
              tab_order << i_widget.slug if i_widget } end
          panes_order[i_pane.slug] = tab_order if not tab_order.empty? end }
      ui_tab_order = (UserConfig[:ui_tab_order] || {}).melt
      ui_tab_order[i_window.slug] = panes_order
      UserConfig[:ui_tab_order] = ui_tab_order
    end
  end

  # ペインを順序リストから削除する
  # ==== Args
  # [i_pane] ペイン
  def pane_order_delete(i_pane)
    order = UserConfig[:ui_tab_order].melt
    i_window = i_pane.parent
    order[i_window.slug] = order[i_window.slug].melt
    order[i_window.slug].delete(i_pane.slug)
    UserConfig[:ui_tab_order] = order
  end

  # _cuscadable_ に対応するGtkオブジェクトを返す
  # ==== Args
  # [cuscadable] ウィンドウ、ペイン、タブ、タイムライン等
  # ==== Return
  # 対応するGtkオブジェクト
  def widgetof(cuscadable)
    type_strict cuscadable => :slug
    result = @slug_dictionary.get(cuscadable)
    if result and result.destroyed?
      nil
    else
      result end end

  # Gtkオブジェクト _widget_ に対応するウィジェットのオブジェクトを返す
  # ==== Args
  # [widget] Gtkウィジェット
  # ==== Return
  # _widget_ に対応するウィジェットオブジェクトまたは偽
  def find_implement_widget_by_gtkwidget(widget)
    @slug_dictionary.imaginally_by_gtk(widget) end
end

module Plugin::Gtk
  class GtkError < Exception
  end end
