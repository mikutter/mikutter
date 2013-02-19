# -*- coding:utf-8 -*-
require File.expand_path(File.join(File.dirname(__FILE__), "shortcutkey_listview"))

Plugin.create :shortcutkey do

  filter_keypress do |key, widget, executed|
    type_strict key => String, widget => Plugin::GUI::Widget
    notice "key pressed #{key} #{widget.inspect}"
    keybinds = (UserConfig[:shortcutkey_keybinds] || Hash.new)
    commands = lazy{ Plugin.filtering(:command, Hash.new).first }
    timeline = widget.is_a?(Plugin::GUI::Timeline) ? widget : widget.active_class_of(Plugin::GUI::Timeline)
    event = Plugin::GUI::Event.new(:contextmenu, widget, timeline ? timeline.selected_messages : [])
    keybinds.values.each{ |behavior|
      if behavior[:key] == key
        cmd = commands[behavior[:slug]]
        if cmd and widget.class.find_role_ancestor(cmd[:role])
          if cmd[:condition] === event
            notice "command executed :#{behavior[:slug]}"
            executed = true
            cmd[:exec].call(event) end end end }
    [key, widget, executed] end

  settings "ショートカットキー" do
    listview = Plugin::Shortcutkey::ShortcutKeyListView.new
    pack_start(Gtk::HBox.new(false, 4).add(listview).closeup(listview.buttons(Gtk::VBox)))
  end

end
