# -*- coding: utf-8 -*-

require File.expand_path File.join(File.dirname(__FILE__), 'builder')
require File.expand_path File.join(File.dirname(__FILE__), 'basic_settings')

Plugin.create(:settings) do

  def setting_window
    return @window if defined?(@window) and @window
    @window = window = Gtk::Window.new
    widgets_dict = {}
    menu = menu_widget(widgets_dict)
    settings = Gtk::VBox.new.set_no_show_all(true).show
    scrolled = Gtk::ScrolledWindow.new.set_hscrollbar_policy(Gtk::POLICY_NEVER)
    Plugin.filtering(:defined_settings, []).first.each{ |title, definition, plugin|
      iter = menu.model.append
      iter[0] = title
      widgets_dict[title] = box = Plugin::Setting.new
      box.instance_eval(&definition)
      settings.closeup(box)
    }
    window.ssc(:destroy) {
      @window = nil
      false }

    window.add(Gtk::HPaned.new.add1(menu).add2(scrolled.add_with_viewport(settings))) end

  def menu_widget(widgets_dict)
    column = Gtk::TreeViewColumn.new("", Gtk::CellRendererText.new, text: 0)
    menumodel = Gtk::ListStore.new(String)
    menu = Gtk::TreeView.new(menumodel).set_headers_visible(false)
    menu.append_column(column)
    menu.ssc(:cursor_changed) {
      active_title = menu.selection.selected[0]
      widgets_dict.each { |title, widget|
        if active_title == title
          widgets_dict[title].show_all
        else
          widgets_dict[title].hide end }
      false }
    menu.set_width_request(HYDE) end

  on_gui_setting do
    setting_window.show_all end

end
