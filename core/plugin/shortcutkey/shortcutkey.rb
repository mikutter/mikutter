# -*- coding:utf-8 -*-
require_relative 'shortcutkey_listview'

Plugin.create :shortcutkey do

  filter_keypress do |key, widget, executed|
    type_strict key => String, widget => Plugin::GUI::Widget
    keybinds = (UserConfig[:shortcutkey_keybinds] || Hash.new)
    commands = lazy{ Plugin.filtering(:command, Hash.new).first }
    timeline = widget.is_a?(Plugin::GUI::Timeline) ? widget : widget.active_class_of(Plugin::GUI::Timeline)
    current_world, = Plugin.filtering(:world_current, nil)
    keybinds.values.lazy.select{|keyconf|
      keyconf[:key] == key
    }.select{|keyconf|
      role = commands.dig(keyconf[:slug], :role)
      role && widget.class.find_role_ancestor(role)
    }.map{|keyconf|
      [ commands[keyconf[:slug]],
        Plugin::GUI::Event.new(
          event: :contextmenu,
          widget: widget,
          messages: timeline ? timeline.selected_messages : [],
          world: world_by_uri(keyconf[:world]) || current_world
        )
      ]
    }.select{|command, event|
      command[:condition] === event
    }.each do |command, event|
      executed = true
      command[:exec].(event)
    end
    [key, widget, executed]
  end

  settings _("ショートカットキー") do
    listview = Plugin::Shortcutkey::ShortcutKeyListView.new(Plugin[:shortcutkey])
    filter_entry = listview.filter_entry = Gtk::Entry.new
    filter_entry.primary_icon_pixbuf = Skin['search.png'].pixbuf(width: 24, height: 24)
    filter_entry.ssc(:changed){
      listview.model.refilter
    }
    pack_start(Gtk::VBox.new(false, 4).
               closeup(filter_entry).
               add(Gtk::HBox.new(false, 4).
                   add(listview).
                   closeup(listview.buttons(Gtk::VBox))))
  end

  def world_by_uri(uri)
    Enumerator.new{|y| Plugin.filtering(:worlds, y) }.find{|w| w.uri.to_s == uri }
  end

end
