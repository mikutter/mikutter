# -*- coding:utf-8 -*-
require_relative 'shortcutkey_listview'

Plugin.create :shortcutkey do

  filter_keypress do |key, widget, executed|
    type_strict key => String, widget => Plugin::GUI::Widget
    keybinds = (UserConfig[:shortcutkey_keybinds] || Hash.new)
    commands = lazy{ Plugin.filtering(:command, Hash.new).first }
    timeline = widget.is_a?(Plugin::GUI::Timeline) ? widget : widget.active_class_of(Plugin::GUI::Timeline)
    event = Plugin::GUI::Event.new(:contextmenu, widget, timeline ? timeline.selected_messages : [])
    keybinds.values.each{ |behavior|
      if behavior[:key] == key
        cmd = commands[behavior[:slug]]
        if cmd and widget.class.find_role_ancestor(cmd[:role])
          if cmd[:condition] === event
            executed = true
            cmd[:exec].call(event) end end end }
    [key, widget, executed] end

  settings _("ショートカットキー") do
    listview = Plugin::Shortcutkey::ShortcutKeyListView.new(Plugin[:shortcutkey])
    filter_entry = listview.filter_entry = Gtk::Entry.new
    filter_entry.primary_icon_pixbuf = Skin[:search].pixbuf(width: 24, height: 24)
    filter_entry.ssc(:changed){
      listview.model.refilter
    }
    pack_start(Gtk::VBox.new(false, 4).
               closeup(filter_entry).
               add(Gtk::HBox.new(false, 4).
                   add(listview).
                   closeup(listview.buttons(Gtk::VBox))))
  end

end
