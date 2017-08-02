# -*- coding: utf-8 -*-
miquire :mui, 'form_dsl', 'form_dsl_select', 'form_dsl_multi_select'

class Plugin::Extract::OptionWidget < Gtk::VBox
  include Gtk::FormDSL

  def create_inner_setting
    self.class.new(@plugin, @extract)
  end

  def initialize(plugin, extract)
    @plugin = plugin
    @extract = extract
    super()
  end

  def [](key)
    case key
    when :icon, :sound
      @extract[key].to_s
    else
      @extract[key]
    end
  end

  def []=(key, value)
    case key
    when :icon, :sound
      @extract[key] = value.empty? ? nil : value
    else
      @extract[key] = value
    end
    @extract.notify_update
    value
  end
end
