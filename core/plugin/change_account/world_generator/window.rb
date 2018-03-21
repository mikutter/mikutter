# -*- coding: utf-8 -*-

module Plugin::ChangeAccount
  class WorldGenerator < Gtk::Dialog
    def initialize(title:, plugin:)
      super(title)
      @plugin = plugin
      @container = Controller.new(plugin, &proc)
      @promise = promise
      set_size_request(640, 480)
      set_window_position(Gtk::Window::POS_CENTER)
      add_button(Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK)
      add_button(Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL)
      vbox.pack_start(@container)
      register_response_listener
    end

  end
end
