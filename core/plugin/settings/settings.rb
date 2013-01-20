# -*- coding: utf-8 -*-

require File.expand_path File.join(File.dirname(__FILE__), 'builder')
require File.expand_path File.join(File.dirname(__FILE__), 'basic_settings')

Plugin.create(:settings) do

  command(:open_setting,
          name: '設定',
          condition: lambda{ |opt| true },
          visible: true,
          icon: Skin.get("settings.png"),
          role: :window) do |opt|
    setting_window.show_all
  end

  on_open_setting do
    setting_window.show_all end

  def setting_window
    return @window if defined?(@window) and @window
    record_order = UserConfig[:settings_menu_order] || ["基本設定", "入力", "表示", "通知", "ショートカットキー", "アクティビティ", "アカウント情報"]
    @window = window = ::Gtk::Window.new("設定")
    window.set_size_request(320, 240)
    window.set_default_size(640, 480)
    widgets_dict = {}
    menu = menu_widget(widgets_dict)
    settings = ::Gtk::VBox.new.set_no_show_all(true).show
    scrolled = ::Gtk::ScrolledWindow.new.set_hscrollbar_policy(::Gtk::POLICY_NEVER)
    Plugin.filtering(:defined_settings, []).first.each{ |title, definition, plugin|
      iter = menu.model.append
      iter[0] = title
      iter[1] = (record_order.index(title) || record_order.size)
      widgets_dict[title] = box = Plugin::Settings.new
      box.instance_eval(&definition)
      settings.closeup(box) }
    window.ssc(:destroy) {
      @window = nil
      false }

    scrolled_menu = ::Gtk::ScrolledWindow.new.set_policy(::Gtk::POLICY_NEVER, ::Gtk::POLICY_AUTOMATIC)

    window.add(::Gtk::HPaned.new.add1(scrolled_menu.add_with_viewport(menu)).add2(scrolled.add_with_viewport(settings))) end

  def menu_widget(widgets_dict)
    column = ::Gtk::TreeViewColumn.new("", ::Gtk::CellRendererText.new, text: 0)
    menumodel = ::Gtk::ListStore.new(String, Integer)
    menumodel.set_sort_column_id(1, order = ::Gtk::SORT_ASCENDING)
    menu = ::Gtk::TreeView.new(menumodel).set_headers_visible(false)
    menu.append_column(column)
    menu.signal_connect(:cursor_changed) {
      if menu.selection.selected
        active_title = menu.selection.selected[0]
        widgets_dict.each { |title, widget|
          if active_title == title
            widgets_dict[title].show_all
          else
            widgets_dict[title].hide end } end
      false }
    menu.set_width_request(HYDE) end

end
