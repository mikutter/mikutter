# -*- coding: utf-8 -*-

module Mainloop

  def before_mainloop
    Gtk.init_add{ Gtk.quit_add(Gtk.main_level){ SerialThreadGroup.force_exit! } }
  end

  def mainloop
    Gtk.main
  end

  def exception_filter(e)
    Gtk.exception ? Gtk.exception : e end

end
