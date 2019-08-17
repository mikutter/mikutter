# -*- coding: utf-8 -*-

module Mainloop

  def mainloop
    loop do
      end_flag = true
      while Gtk.events_pending?
        end_flag = Gtk.main_iteration
      end
      break if !end_flag || Gtk.exception
      sleep 0.02
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
