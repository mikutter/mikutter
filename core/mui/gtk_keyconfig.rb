# -*- coding: utf-8 -*-
miquire :mui, 'extension'

require 'gtk2'

class Gtk::KeyConfig < Gtk::Button

  attr_accessor :change_hook, :title, :keycode

  def initialize(title, default_key='', *args)
    @title = title
    self.keycode = default_key.to_s
    @change_hook = nil
    super(*args)
    self.add(buttonlabel)
    self.ssc(:clicked, &method(:clicked_event))
  end

  def buttonlabel
    @buttonlabel ||= Gtk::Label.new(keycode)
  end

  private

  def clicked_event(event)
    box = Gtk::VBox.new
    label = Gtk::Label.new
    button = Gtk::Button.new
    dialog = Gtk::Dialog.new(title, self.get_ancestor(Gtk::Window), Gtk::Dialog::MODAL,
                             [ Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK])
    label.text = keycode
    box.border_width = 20
    button.add(label)
    box.pack_start(Gtk::Label.new('下のボタンをクリックして、割り当てたいキーを押してください。'))
    box.pack_start(button)
    button.signal_connect(:key_press_event, &key_set(label))
    button.signal_connect(:button_press_event, &button_set(label))
    dialog.vbox.add(box)
    dialog.show_all
    dialog.run
    dialog.destroy
    true
  end

  def key_set(label)
    ->(widget, event) do
      self.keycode = Gtk.keyname([event.keyval, event.state])
      buttonlabel.text = label.text = keycode
      self.change_hook.call(keycode) if self.change_hook
      true
    end
  end

  def button_set(label)
    ->(widget, event) do
      self.keycode = Gtk.buttonname([event.event_type, event.button, event.state])
      buttonlabel.text = label.text = keycode
      self.change_hook.call(keycode) if self.change_hook
      true
    end
  end

end
