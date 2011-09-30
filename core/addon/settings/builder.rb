# -*- coding: utf-8 -*-

class Plugin::Setting < Gtk::VBox
  def multitext(label, config, optional=nil)
    container = Gtk::HBox.new(false, 0)
    input = Gtk::TextView.new
    input.tooltip optional if optional
    input.wrap_mode = Gtk::TextTag::WRAP_CHAR
    input.border_width = 2
    input.accepts_tab = false
    input.editable = true
    input.width_request = HYDE
    input.buffer.text = UserConfig[config] || ''
    container.pack_start(Gtk::Label.new(label), false, true, 0) if label
    container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(input), true, true, 0)
    input.buffer.ssc('changed'){ |widget|
      UserConfig[config] = widget.text }
    closeup container
  end
end
