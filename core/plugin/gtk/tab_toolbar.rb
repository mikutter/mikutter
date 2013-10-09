# -*- coding: utf-8 -*-

require "gtk2"

require File.expand_path File.join(File.dirname(__FILE__), 'toolbar_generator')

class Gtk::TabToolbar < Gtk::HBox
  def initialize(imaginally, *args)
    type_strict imaginally => Plugin::GUI::TabToolbar
    @imaginally = imaginally
    super(*args)
  end

  def set_button
    self.children.each(&method(:remove))
    Plugin::Gtk::ToolbarGenerator.generate(self,
                                           Plugin::GUI::Event.new(:tab_toolbar, @imaginally.parent, []),
                                           :tab)
  end
end
