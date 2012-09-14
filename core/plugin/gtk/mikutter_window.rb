# -*- coding: utf-8 -*-

require "gtk2"

class Gtk::MikutterWindow < Gtk::Window

  attr_reader :panes

  def initialize(*args)
    super
    @container = Gtk::VBox.new(false, 0)
    @panes = Gtk::HBox.new(true, 0)
    add(@container.pack_start(@panes))
  end

end
