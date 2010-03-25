miquire :mui, 'extension'

require 'gtk2'

class Gtk::KeyConfig < Gtk::Button

  attr_accessor :keycode
  attr_accessor :change_hook

  def initialize(title, default_key=[], *args)
    Gtk::Lock.synchronize do
      @keycode = default_key
      @change_hook = nil
      super(*args)
      buttonlabel = Gtk::Label.new(keyname(self.keycode))
      self.add(buttonlabel)
      self.signal_connect('clicked'){
        Gtk::Lock.synchronize do
          box = Gtk::VBox.new
          label = Gtk::Label.new
          button = Gtk::Button.new
          dialog = Gtk::Dialog.new(title, self.get_ancestor(Gtk::Window), Gtk::Dialog::MODAL,
                                   [ Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK])
          label.text = keyname(self.keycode)
          box.border_width = 20
          button.add(label)
          box.pack_start(Gtk::Label.new('下のボタンをクリックして、割り当てたいキーを押してください。'))
          box.pack_start(button)
          button.signal_connect('key_press_event'){ |widget, event|
            Gtk::Lock.synchronize do
              self.keycode = [event.keyval, event.state]
              buttonlabel.text = label.text = keyname(self.keycode)
            end
            self.change_hook.call(self.keycode) if self.change_hook
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

  def keyname(key)
    if key.empty? then
      return '(割り当てなし)'
    else
      Gtk::Lock.synchronize do
        r = ""
        r << 'Control + ' if (key[1] & Gdk::Window::CONTROL_MASK) != 0
        r << 'Shift + ' if (key[1] & Gdk::Window::SHIFT_MASK) != 0
        r << 'Alt + ' if (key[1] & Gdk::Window::META_MASK) != 0
        r << 'Super + ' if (key[1] & Gdk::Window::SUPER_MASK) != 0
        r << 'Hyper + ' if (key[1] & Gdk::Window::HYPER_MASK) != 0
        return r + Gdk::Keyval.to_name(key[0])
      end
    end
  end
end
