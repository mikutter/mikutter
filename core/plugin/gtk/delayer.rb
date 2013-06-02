# -*- coding: utf-8 -*-

require "gtk2"
miquire :lib, "delayer"

Module.new do

  def self.boot
    Gtk.idle_add_priority(GLib::PRIORITY_LOW) {
      begin
        Delayer.run
      rescue => e
        into_debug_mode(e)
        Gtk.main_quit end
      false }
  end

  Delayer.register_remain_hook do
    boot
  end

  boot
end
