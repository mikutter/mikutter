# -*- coding: utf-8 -*-

module Mainloop

  def mainloop
    catch(:__exit_mikutter) do
      loop do
        while Gtk.events_pending?
          Gtk.main_iteration
          throw :__exit_mikutter if Gtk.exception
        end
        while not Delayer.empty?
          Delayer.run
          Gtk.main_iteration if Gtk.events_pending?
        end
        sleep 0.02
      end
    end
  rescue Interrupt,SystemExit,SignalException => exception
    raise exception
  rescue Exception => exception
    Gtk.exception = exception
  ensure
    SerialThreadGroup.force_exit!
  end

  def exception_filter(e)
    Gtk.exception ? Gtk.exception : e end

end
