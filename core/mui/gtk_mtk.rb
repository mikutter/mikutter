# -*- coding:utf-8 -*-

require_relative '../utils'
miquire :mui, 'extension'
miquire :mui, 'message_picker'
miquire :mui, 'crud'
miquire :mui, 'keyconfig'
miquire :mui, 'selectbox'

require 'gtk2'

module Mtk
  extend self
  extend Gem::Deprecate

  def adjustment(name, config, min, max)
    container = Gtk::HBox.new(false, 0)
    container.pack_start(Gtk::Label.new(name), false, true, 0)
    adj = Gtk::Adjustment.new((UserConfig[config] or min), min*1.0, max*1.0, 1.0, 5.0, 0.0)
    spinner = Gtk::SpinButton.new(adj, 0, 0)
    spinner.wrap = true
    adj.ssc(:value_changed){ |widget, e|
      UserConfig[config] = widget.value.to_i
      false
    }
    container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(spinner), true, true, 0)
  end
  deprecate :adjustment, :none, 2020, 8

  # [values] {値 => ラベル(String)} のようなHash
  def chooseone(key, label, values)
    values.freeze
    if key.respond_to?(:call)
      proc = key
    else
      proc = lambda{ |new|
        if new === nil
          UserConfig[key]
        else
          UserConfig[key] = new end } end
    container = Gtk::HBox.new(false, 0)
    input = Gtk::ComboBox.new(true)
    sorted_keys = values.keys.freeze
    sorted_keys.each{ |x|
      input.append_text(values[x].respond_to?(:call) ? values[x].call(nil) : values[x])
    }
    input.active = (sorted_keys.index{ |i| i.to_s == proc.call(*[nil, input][0, proc.arity]).to_s } or 0)
    input.ssc(:changed){ |widget|
      proc.call(*[sorted_keys[widget.active], widget][0, proc.arity])
      nil
    }
    container.pack_start(Gtk::Label.new(label), false, true, 0) if label
    container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(input), true, true, 0)
  end

  def choosemany(key, label, values)
    values.freeze
    if key.respond_to?(:call)
      proc = key
    else
      proc = lambda{ |new|
        if new === nil
          UserConfig[key] or []
        else
          UserConfig[key] = new end } end
    input = Gtk::SelectBox.new(values, proc.call(*[nil, input][0, proc.arity])){ |selected|
      proc.call(*[selected, input][0, proc.arity])
    }
    if label
      Gtk::HBox.new(false, 0).
        pack_start(Gtk::Label.new(label), false, true, 0).
        pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(input), true, true, 0)
    else
      input end end
  deprecate :choosemany, :none, 2020, 8

  def boolean(key, label)
    if key.respond_to?(:call)
      proc = key
    else
      proc = lambda{ |new|
        if new === nil
          UserConfig[key]
        else
          UserConfig[key] = new end } end
    input = Gtk::CheckButton.new(label)
    input.active = proc.call(*[nil, input][0, proc.arity])
    input.ssc(:toggled){ |widget|
      proc.call(*[widget.active?, widget][0, proc.arity]) }
    return input
  end
  deprecate :boolean, :none, 2020, 8

  def message_picker(key)
    if key.respond_to?(:call)
      proc = key
    else
      proc = lambda{ |new|
        if new.nil?
          UserConfig[key]
        else
          UserConfig[key] = new.freeze end } end
    input = Gtk::MessagePicker.new(proc.call(*[nil, input][0, proc.arity])){
        proc.call(*[ input.to_a, input][0, proc.arity]) }
    input.ssc(:destroy){
      proc.call(*[ input.to_a, input][0, proc.arity]) }
    return input
  end
  deprecate :message_picker, :none, 2020, 8

  def default_or_custom(key, title, default_label, custom_label)
    group = default = Gtk::RadioButton.new(default_label)
    custom = Gtk::RadioButton.new(group, custom_label)
    input = Gtk::Entry.new
    input.text = UserConfig[:url_open_command] if UserConfig[:url_open_command].is_a?(String)
    default.active = !(input.sensitive = custom.active = UserConfig[key])
    default.ssc(:toggled){ |widget|
      UserConfig[key] = nil
      input.sensitive = !widget.active?
    }
    custom.ssc(:toggled){ |widget|
      UserConfig[key] = input.text
      input.sensitive = widget.active?
    }
    input.ssc(:changed){ |widget|
      UserConfig[key] = widget.text
    }
    self.group(title, default, Gtk::HBox.new(false, 0).add(custom).add(input))
  end
  deprecate :default_or_custom, :none, 2020, 8

  def input(key, label, visibility=true, &callback)
    if key.respond_to?(:call)
      proc = key
    else
      proc = lambda{ |new|
        if new
          UserConfig[key] = new
        else
          UserConfig[key].to_s end } end
    container = Gtk::HBox.new(false, 0)
    input = Gtk::Entry.new
    input.text = proc.call(nil)
    input.visibility = visibility
    container.pack_start(Gtk::Label.new(label), false, true, 0) if label
    container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(input), true, true, 0)
    input.ssc(:changed){ |widget|
      proc.call(widget.text) }
    callback.call(container, input) if block_given?
    return container
  end
  deprecate :input, :none, 2020, 8

  def keyconfig(key, title)
    if key.respond_to?(:call)
      proc = key
    else
      proc = lambda{ |new|
        if new
          UserConfig[key] = new
        else
          UserConfig[key].to_s end } end
    keyconfig = Gtk::KeyConfig.new(title, proc.call(nil))
    container = Gtk::HBox.new(false, 0)
    container.pack_start(Gtk::Label.new(title), false, true, 0)
    container.closeup(keyconfig.right)
    keyconfig.change_hook = proc
    return container
  end
  deprecate :keyconfig, :none, 2020, 8

  def group(title, *children)
    group = Gtk::Frame.new.set_border_width(8)
    if(title.is_a?(Gtk::Widget))
      group.set_label_widget(title)
    else
      group.set_label(title) end
    box = Gtk::VBox.new(false, 0).set_border_width(4)
    group.add(box)
    children.each{ |w|
      box.pack_start(w, false)
    }
    group
  end
  deprecate :group, :none, 2020, 8

  def expander(title, expanded, *children)
    group = Gtk::Expander.new(title).set_border_width(8)
    group.expanded = expanded
    box = Gtk::VBox.new(false, 0).set_border_width(4)
    group.add(box)
    children.each{ |w|
      box.pack_start(w, false)
    }
    group
  end
  deprecate :expander, :none, 2020, 8

  def fileselect(*)
    raise Mtk::Read994Error, 'It\'s always crash when this method call. see: https://dev.mikutter.hachune.net/issues/994'
  end
  deprecate :fileselect, :none, 2020, 8

  def _colorselect(key, label)
    color = UserConfig[key]
    button = Gtk::ColorButton.new((color and Gdk::Color.new(*color)))
    button.title = label
    button.ssc(:color_set){ |w|
      UserConfig[key] = w.color.to_a }
    button end

  def _fontselect(key, label)
    button = Gtk::FontButton.new(UserConfig[key])
    button.title = label
    button.ssc(:font_set){ |w|
      UserConfig[key] = w.font_name }
    button end

  def fontselect(key, label)
    Gtk::HBox.new(false, 0).add(Gtk::Label.new(label).left).closeup(_fontselect(key, label))
  end
  deprecate :fontselect, :none, 2020, 8

  def colorselect(key, label)
    Gtk::HBox.new(false, 0).add(Gtk::Label.new(label).left).closeup(_colorselect(key, label))
  end
  deprecate :colorselect, :none, 2020, 8

  def fontcolorselect(font, color, label)
    self.fontselect(font, label).closeup(_colorselect(color, label))
  end
  deprecate :fontcolorselect, :none, 2020, 8

  def accountdialog_button(*)
    raise Mtk::Read994Error, 'It\'s always crash when this method call. see: https://dev.mikutter.hachune.net/issues/994'
  end
  deprecate :accountdialog_button, :none, 2020, 8

  def account_dialog_inner(*)
    raise Mtk::Read994Error, 'It\'s always crash when this method call. see: https://dev.mikutter.hachune.net/issues/994'
  end

  def adi(symbol, label)
    input(lambda{ |new| UserConfig[symbol] }, label){ |c, i| yield(i) } end

  def account_dialog(*)
    raise Mtk::Read994Error, 'It\'s always crash when this method call. see: https://dev.mikutter.hachune.net/issues/994'
  end

  def alert(*)
    raise Mtk::Read994Error, 'It\'s always crash when this method call. see: https://dev.mikutter.hachune.net/issues/994'
  end

  def dialog_button(*)
    raise Mtk::Read994Error, 'It\'s always crash when this method call. see: https://dev.mikutter.hachune.net/issues/994'
  end

  def scrolled_dialog(*)
    raise Mtk::Read994Error, 'It\'s always crash when this method call. see: https://dev.mikutter.hachune.net/issues/994'
  end

  def dialog(*)
    raise Mtk::Read994Error, 'It\'s always crash when this method call. see: https://dev.mikutter.hachune.net/issues/994'
  end

  class Mtk::ValidateError < StandardError;  end
  class Mtk::Read994Error < StandardError;  end

end
