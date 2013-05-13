# -*- coding:utf-8 -*-

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'utils'))
miquire :mui, 'extension'
miquire :mui, 'message_picker'
miquire :mui, 'crud'
miquire :mui, 'keyconfig'
miquire :mui, 'selectbox'

require 'gtk2'

module Mtk
  def self.adjustment(name, config, min, max)
    container = Gtk::HBox.new(false, 0)
    container.pack_start(Gtk::Label.new(name), false, true, 0)
    adj = Gtk::Adjustment.new((UserConfig[config] or min), min*1.0, max*1.0, 1.0, 5.0, 0.0)
    spinner = Gtk::SpinButton.new(adj, 0, 0)
    spinner.wrap = true
    adj.signal_connect('value-changed'){ |widget, e|
      UserConfig[config] = widget.value.to_i
      false
    }
    container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(spinner), true, true, 0)
  end

  def self.chooseone(key, label, values)
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
    sorted = values.keys.sort_by(&:to_s).freeze
    sorted.each{ |x|
      input.append_text(values[x].respond_to?(:call) ? values[x].call(nil) : values[x])
    }
    input.active = (sorted.index{ |i| i.to_s == proc.call(*[nil, input][0, proc.arity]).to_s } or 0)
    proc.call(*[sorted[input.active], input][0, proc.arity])
    input.signal_connect('changed'){ |widget|
      proc.call(*[sorted[widget.active], widget][0, proc.arity])
      nil
    }
    container.pack_start(Gtk::Label.new(label), false, true, 0) if label
    container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(input), true, true, 0)
  end

  def self.choosemany(key, label, values)
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

  def self.boolean(key, label)
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
    input.signal_connect('toggled'){ |widget|
      proc.call(*[widget.active?, widget][0, proc.arity]) }
    return input
  end

  def self.message_picker(key)
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
    input.signal_connect(:destroy){
      proc.call(*[ input.to_a, input][0, proc.arity]) }
    return input
  end

  def self.default_or_custom(key, title, default_label, custom_label)
    group = default = Gtk::RadioButton.new(default_label)
    custom = Gtk::RadioButton.new(group, custom_label)
    input = Gtk::Entry.new
    input.text = UserConfig[:url_open_command] if UserConfig[:url_open_command].is_a?(String)
    default.active = !(input.sensitive = custom.active = UserConfig[key])
    default.signal_connect('toggled'){ |widget|
      UserConfig[key] = nil
      input.sensitive = !widget.active?
    }
    custom.signal_connect('toggled'){ |widget|
      UserConfig[key] = input.text
      input.sensitive = widget.active?
    }
    input.signal_connect('changed'){ |widget|
      UserConfig[key] = widget.text
    }
    self.group(title, default, Gtk::HBox.new(false, 0).add(custom).add(input))
  end

  def self.input(key, label, visibility=true, &callback)
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
    input.signal_connect('changed'){ |widget|
      proc.call(widget.text) }
    callback.call(container, input) if block_given?
    return container
  end

  def self.keyconfig(key, title)
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

  def self.group(title, *children)
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

  def self.expander(title, expanded, *children)
    group = Gtk::Expander.new(title).set_border_width(8)
    group.expanded = expanded
    box = Gtk::VBox.new(false, 0).set_border_width(4)
    group.add(box)
    children.each{ |w|
      box.pack_start(w, false)
    }
    group
  end

  def self.fileselect(key, label, current=Dir.pwd)
    container = input = nil
    self.input(key, label){ |c, i|
      container = c
      input = i }
    button = Gtk::Button.new('参照')
    container.pack_start(button, false)
    button.signal_connect('clicked'){ |widget|
      dialog = Gtk::FileChooserDialog.new("Open File",
                                          widget.get_ancestor(Gtk::Window),
                                          Gtk::FileChooser::ACTION_OPEN,
                                          nil,
                                          [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                                          [Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT])
      dialog.current_folder = File.expand_path(current)
      if dialog.run == Gtk::Dialog::RESPONSE_ACCEPT
        UserConfig[key] = dialog.filename
        input.text = dialog.filename
      end
      dialog.destroy
    }
    container
  end

  def self._colorselect(key, label)
    color = UserConfig[key]
    button = Gtk::ColorButton.new((color and Gdk::Color.new(*color)))
    button.title = label
    button.signal_connect('color-set'){ |w|
      UserConfig[key] = w.color.to_a }
    button end

  def self._fontselect(key, label)
    button = Gtk::FontButton.new(UserConfig[key])
    button.title = label
    button.signal_connect('font-set'){ |w|
      UserConfig[key] = w.font_name }
    button end

  def self.fontselect(key, label)
    Gtk::HBox.new(false, 0).add(Gtk::Label.new(label).left).closeup(_fontselect(key, label))
  end

  def self.colorselect(key, label)
    Gtk::HBox.new(false, 0).add(Gtk::Label.new(label).left).closeup(_colorselect(key, label))
  end

  def self.fontcolorselect(font, color, label)
    self.fontselect(font, label).closeup(_colorselect(color, label))
  end

  def self.accountdialog_button(label, kuser, lvuser,  kpasswd, lvpasswd, &validator)
    btn = Gtk::Button.new(label)
    btn.signal_connect('clicked'){
      self.account_dialog(label, kuser, lvuser,  kpasswd, lvpasswd, &validator) }
    btn
  end

  def self.account_dialog_inner(kuser, lvuser,  kpasswd, lvpasswd, cancel=true)
    def entrybox(label, visibility=true, default="")
      container = Gtk::HBox.new(false, 0)
      input = Gtk::Entry.new
      input.text = default
      input.visibility = visibility
      container.pack_start(Gtk::Label.new(label), false, true, 0)
      container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(input), true, true, 0)
      return container, input
    end
    box = Gtk::VBox.new(false, 8)
    user, user_input = entrybox(lvuser, true, (UserConfig[kuser] or ""))
    pass, pass_input = entrybox(lvpasswd, false)
    return box.closeup(user).closeup(pass), user_input, pass_input
  end

  def self.adi(symbol, label)
    input(lambda{ |new| UserConfig[symbol] }, label){ |c, i| yield(i) } end

  def self.account_dialog(label, kuser, lvuser,  kpasswd, lvpasswd, cancel=true, &validator)
    alert_thread = if(Thread.main != Thread.current) then Thread.current end
    dialog = Gtk::Dialog.new(label)
    dialog.window_position = Gtk::Window::POS_CENTER
    iuser = ipass = nil
    container = Gtk::VBox.new(false, 8).
      closeup(adi(kuser, lvuser){ |i| iuser = i }).
      closeup(adi(kpasswd, lvpasswd){ |i| ipass = i })
    dialog.vbox.pack_start(container, true, true, 30)
    dialog.add_button(Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK)
    dialog.add_button(Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL) if cancel
    dialog.default_response = Gtk::Dialog::RESPONSE_OK
    quit = lambda{
      dialog.hide_all.destroy
      Gtk.main_iteration_do(false)
      Gtk::Window.toplevels.first.show
      if alert_thread
        alert_thread.run
      else
        Gtk.main_quit
      end }
    dialog.signal_connect("response"){ |widget, response|
      if response == Gtk::Dialog::RESPONSE_OK
        if validator.call(iuser.text, ipass.text)
          UserConfig[kuser] = iuser.text
          UserConfig[kpasswd] = ipass.text
          quit.call
        else
          alert("#{lvuser}か#{lvpasswd}が違います")
        end
      elsif (cancel and response == Gtk::Dialog::RESPONSE_CANCEL) or
          response == Gtk::Dialog::RESPONSE_DELETE_EVENT
        quit.call
      end }
    dialog.signal_connect("destroy") {
      false
    }
    container.show
    dialog.show_all
    Gtk::Window.toplevels.first.hide
    if(alert_thread)
      Thread.stop
    else
      Gtk::main
    end
  end

  def self.alert(message)
    dialog = Gtk::MessageDialog.new(nil,
                                    Gtk::Dialog::DESTROY_WITH_PARENT,
                                    Gtk::MessageDialog::QUESTION,
                                    Gtk::MessageDialog::BUTTONS_CLOSE,
                                    message)
    dialog.run
    dialog.destroy
  end

  def self.dialog_button(label, callback = Proc.new)
    btn = Gtk::Button.new(label)
    btn.signal_connect('clicked'){
      params = callback.call
      self.dialog(label, params[:container], &params[:success]) }
    btn
  end

  def self.scrolled_dialog(title, container, parent=nil, expand=true, &block)
    dialog(title,
           Gtk::ScrolledWindow.new.
           set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC).
           add_with_viewport(container),
           parent, expand, &block) end

  def self.dialog(title, container, parent=nil, expand=true, &block)
    parent_window = parent and parent.toplevel.toplevel? and parent.toplevel
    result = nil
    dialog = Gtk::Dialog.new("#{title} - " + Environment::NAME)
    dialog.set_size_request(640, 480)
    dialog.window_position = Gtk::Window::POS_CENTER
    dialog.vbox.pack_start(container, expand, true, 30)
    dialog.add_button(Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK)
    dialog.add_button(Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL) if block_given?
    dialog.signal_connect('response'){ |widget, response|
      if block and response == Gtk::Dialog::RESPONSE_OK
        begin
          result = block.call(*[response, dialog][0,block.arity])
        rescue Mtk::ValidateError => e
          dialog.sensitive = false
          alert = Gtk::Dialog.new("エラー - " + Environment::NAME)
          alert.set_size_request(420, 90)
          alert.window_position = Gtk::Window::POS_CENTER
          alert.vbox.add(Gtk::Label.new(e.to_s))
          alert.add_button(Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK)
          alert.show_all
          alert.signal_connect('response'){
            dialog.sensitive = true
            alert.hide_all.destroy }
          next
        end
      end
      parent_window.sensitive = true if parent_window
      dialog.hide_all.destroy
      Gtk::main_quit
    }
    parent_window.sensitive = false if parent_window
    dialog.show_all
    Gtk::main
    result end

  class Mtk::ValidateError < StandardError;  end

end
