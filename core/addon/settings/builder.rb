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

  def adjustment(name, config, min, max)
    container = Gtk::HBox.new(false, 0)
    container.pack_start(Gtk::Label.new(name), false, true, 0)
    adj = Gtk::Adjustment.new((UserConfig[config] or min), min*1.0, max*1.0, 1.0, 5.0, 0.0)
    spinner = Gtk::SpinButton.new(adj, 0, 0)
    spinner.wrap = true
    adj.signal_connect('value-changed'){ |widget, e|
      UserConfig[config] = widget.value.to_i
      false
    }
    closeup container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(spinner), true, true, 0)
  end

  def boolean(label, key)
    input = Gtk::CheckButton.new(label)
    input.active = UserConfig[key]
    input.signal_connect('toggled'){ |widget|
      UserConfig[key] = widget.active? }
    closeup input end

  def fileselect(label, key, current=Dir.pwd)
    container = input = nil
    Mtk.input(key, label){ |c, i|
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
    closeup container
  end

  def settings(title)
    group = Gtk::Frame.new.set_border_width(8)
    if(title.is_a?(Gtk::Widget))
      group.set_label_widget(title)
    else
      group.set_label(title) end
    box = Plugin::Setting.new.set_border_width(4)
    box.instance_eval(&Proc.new)
    closeup group.add(box)
  end

end
