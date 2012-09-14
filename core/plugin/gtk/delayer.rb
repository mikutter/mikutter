# -*- coding: utf-8 -*-

require "gtk2"

class Delayer
  class << self
    attr_accessor :idle_handler

    def idle_handler_lock
      @idle_handler_lock ||= Mutex.new end

    def on_regist(delayer)
      idle_handler_lock.synchronize {
        @idle_handler ||= Gtk.idle_add_priority(GLib::PRIORITY_LOW) {
          begin
            Delayer.run
          rescue => e
            into_debug_mode(e)
            Gtk.main_quit end
          idle_handler_lock.synchronize {
            if Delayer.empty?
              @idle_handler = nil
              false
            else
              true end } } } end
  end
end
