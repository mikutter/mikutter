# -*- coding: utf-8 -*-
miquire :mui, 'form_dsl', 'form_dsl_select', 'form_dsl_multi_select'

class Plugin::Extract::OptionWidget < Gtk::VBox
  include Gtk::FormDSL

  def create_inner_setting
    self.class.new(@plugin, @extract)
  end

  def initialize(plugin, extract)
    super()
    @plugin = plugin
    @extract = extract
    if block_given?
      instance_eval(&Proc.new)
    end
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

  def method_missing_at_select_dsl(*args, &block)
    @plugin.__send__(*args, &block)
  end

  def method_missing(*args, &block)
    @plugin.__send__(*args, &block)
  end

end
