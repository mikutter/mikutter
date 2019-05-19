# -*- coding: utf-8 -*-

module Mainloop

  def mainloop
    loop do
      Gtk.main
      break if Gtk.exception || Plugin.filtering(:before_mainloop_exit)
      error "Mainloop exited but it's cancelled by filter `:before_mainloop_exit'."
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
