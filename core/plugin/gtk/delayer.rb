# -*- coding: utf-8 -*-

require "gtk2"

class Delayer
  class << self
    attr_accessor :idle_handler

    def idle_handler_lock
      @idle_handler_lock ||= Mutex.new end

    def event_lock
      @event_lock = true
      result = yield
      @event_lock = false
      @idle_handler = nil
      on_regist(nil)
      result end

    def on_regist(delayer)
      idle_handler_lock.synchronize {
        if not(defined?(@event_lock) and @event_lock)
          @idle_handler ||= Gtk.idle_add_priority(GLib::PRIORITY_LOW) {
            next true if @event_lock
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
                true end } } end } end
  end
end
