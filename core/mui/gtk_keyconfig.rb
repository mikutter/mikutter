# -*- coding: utf-8 -*-
miquire :mui, 'extension'

require 'gtk2'

class Gtk::KeyConfig < Gtk::Button

  attr_accessor :keycode
  attr_accessor :change_hook

  def initialize(title, default_key="", *args)
    Gtk::Lock.synchronize do
      if(default_key.respond_to?(:to_s))
        @keycode = default_key.to_s
      else
        @keycode = '' end
      @change_hook = nil
      super(*args)
      buttonlabel = Gtk::Label.new(self.keycode)
      self.add(buttonlabel)
      self.signal_connect('clicked'){
        Gtk::Lock.synchronize do
          box = Gtk::VBox.new
          label = Gtk::Label.new
          button = Gtk::Button.new
          dialog = Gtk::Dialog.new(title, self.get_ancestor(Gtk::Window), Gtk::Dialog::MODAL,
                                   [ Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK])
          label.text = Gtk::keyname(self.keycode)
          box.border_width = 20
          button.add(label)
          box.pack_start(Gtk::Label.new('下のボタンをクリックして、割り当てたいキーを押してください。'))
          box.pack_start(button)
          button.signal_connect('key_press_event'){ |widget, event|
            Gtk::Lock.synchronize do
              self.keycode = [event.keyval, event.state]
              buttonlabel.text = label.text = Gtk::keyname(self.keycode)
            end
            self.change_hook.call(Gtk::keyname(self.keycode)) if self.change_hook
            true
          }
          dialog.vbox.add(box)
          dialog.show_all
          dialog.run
          dialog.destroy
        end
      }
    end
  end
end
