# -*- coding: utf-8 -*-

class Gtk::PseudoMessageWidget

  attr_reader :iter, :event

  def initialize(iter, event, tl)
    @iter, @event, @tl = iter, event, tl
  end

  def message
    @iter[1] end
  alias :to_message :message

  def gen_postbox(m=message, options={})
    @tl.reply(m, options) end

end
