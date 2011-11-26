# -*- coding: utf-8 -*-

require File.expand_path File.join(File.dirname(__FILE__), 'builder')
require File.expand_path File.join(File.dirname(__FILE__), 'basic_settings')

Plugin.create(:settings) do
  book = Gtk::Notebook.new.set_tab_pos(Gtk::POS_TOP).set_scrollable(true)
  onboot do |service|
    Plugin.call(:mui_tab_regist, book, 'Settings', MUI::Skin.get("settings.png")) end

  on_setting_tab_regist do |box, label|
    box = box.call if box.respond_to?(:call)
    container = Gtk::ScrolledWindow.new()
    container.set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_AUTOMATIC)
    container.add_with_viewport(box)
    book.append_page(container, Gtk::Label.new(label))
    book.show_all end

  on_settings do |title, definition|
    box = Plugin::Setting.new
    box.instance_eval(&definition)
    container = Gtk::ScrolledWindow.new()
    container.set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_AUTOMATIC)
    container.add_with_viewport(box)
    book.append_page(container, Gtk::Label.new(title))
    book.show_all end

end
