# -*- coding: utf-8 -*-

class Gtk::PseudoMessageWidget

  attr_reader :iter, :event

  def initialize(iter, event)
    @iter, @event = iter, event
  end

  def message
    @iter[1] end
  alias :to_message :message

  def gen_postbox
    
  end

end
