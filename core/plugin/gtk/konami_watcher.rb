# -*- coding: utf-8 -*-
# なーにがkonami_watcherじゃ

module Gtk
  KONAMI_SEQUENCE = [Gdk::Keyval::GDK_Up,
                     Gdk::Keyval::GDK_Up,
                     Gdk::Keyval::GDK_Down,
                     Gdk::Keyval::GDK_Down,
                     Gdk::Keyval::GDK_Left,
                     Gdk::Keyval::GDK_Right,
                     Gdk::Keyval::GDK_Left,
                     Gdk::Keyval::GDK_Right,
                     Gdk::Keyval::GDK_b,
                     Gdk::Keyval::GDK_a].freeze
  remain = KONAMI_SEQUENCE
  Gtk.key_snooper_install do |grab_widget, event|
    if Gdk::Event::KEY_PRESS == event.event_type
      if remain.first == event.keyval
        remain = remain.cdr
        unless remain
          Plugin.call :konami_activate
          remain = KONAMI_SEQUENCE
        end
      else
        remain = KONAMI_SEQUENCE
      end
    end
    false
  end
end
