# -*- coding: utf-8 -*-

require File.expand_path File.join(File.dirname(__FILE__), 'builder')
require File.expand_path File.join(File.dirname(__FILE__), 'basic_settings')

Plugin.create(:settings) do

  def book
    @book ||= Gtk::Notebook.new.set_tab_pos(Gtk::POS_TOP).set_scrollable(true) end

  def book_labels
    book.children.map{ |child|
      book.get_menu_label(child).text } end

  def settings_add(title, box)
    container = Gtk::ScrolledWindow.new()
    container.set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_AUTOMATIC)
    container.add_with_viewport(box)

    idx = where_should_insert_it(title, book_labels, UserConfig[:tab_order_in_settings] || [])
    book.insert_page_menu(idx, container, Gtk::Label.new(title), Gtk::Label.new(title))

    container.show_all if book.realized? and book.mapped? end

  onboot do |service|
    Plugin.call(:mui_tab_regist, book, 'Settings', MUI::Skin.get("settings.png"))
    book.show_all end

  on_setting_tab_regist do |box, title|
    unless book_labels.include? title
      box = box.call if box.respond_to?(:call)
      settings_add(title, box) end end

  on_settings do |title, definition|
    unless book_labels.include? title
      box = Plugin::Setting.new
      box.instance_eval(&definition)
      settings_add(title, box) end end

  defined = Plugin.filtering(:defined_settings, []).first
  if defined
    defined.each{ |pair|
      title, definition = pair
      box = Plugin::Setting.new
      box.instance_eval(&definition)
      settings_add(title, box) } end

end
