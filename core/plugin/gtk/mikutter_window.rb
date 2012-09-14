# -*- coding: utf-8 -*-

require "gtk2"

class Gtk::MikutterWindow < Gtk::Window

  attr_reader :panes

  def initialize(*args)
    super
    @container = Gtk::VBox.new(false, 0)
    @panes = Gtk::HBox.new(true, 0)
    @postboxes = Gtk::VBox.new(false, 0)
    postbox = Gtk::PostBox.new(Service.primary, :postboxstorage => @postboxes, :delegate_other => true)
    @postboxes.pack_start(postbox)
    set_focus(postbox.post)
    add(@container.closeup(@postboxes).pack_start(@panes))
  end

end
