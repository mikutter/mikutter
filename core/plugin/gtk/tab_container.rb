# -*- coding: utf-8 -*-
require "gtk2"

class Gtk::TabContainer < Gtk::VBox
  attr_reader :i_tab

  def initialize(tab)
    type_strict tab => Plugin::GUI::TabLike
    @i_tab = tab
    super(false, 0)
  end

  def to_sym
    i_tab.slug end
  alias slug to_sym
end
