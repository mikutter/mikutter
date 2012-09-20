# -*- coding: utf-8 -*-

module Plugin::Console
  class ConsoleControl < Gtk::VPaned
    def active
      get_ancestor(Gtk::Window).set_focus(child2) if(get_ancestor(Gtk::Window))
    end
  end
end




