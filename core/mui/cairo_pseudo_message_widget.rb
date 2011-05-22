# -*- coding: utf-8 -*-

class Gtk::PseudoMessageWidget

  attr_reader :message, :event, :widget

  def initialize(message, event, widget)
    @message, @event, @widget = message, event, widget
  end

  alias :to_message :message

  def gen_postbox(m=message, options={})
    widget.reply(m, options) end

end
