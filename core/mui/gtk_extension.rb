miquire :core, 'utils'

require 'gtk2'
require 'monitor'

class Gtk::Lock

  @@monitor = Monitor.new

  def self.synchronize
    raise if Thread.main != Thread.current
    @@monitor.synchronize{
      #GC.synchronize{
        yield
      #}
    }
  end

  def self.lock
    @@monitor.enter
    #GC.lock
  end

  def self.unlock
    #GC.unlock
    @@monitor.exit
  end

end

class Gtk::Widget < Gtk::Object
  def top
    Gtk::Alignment.new(0.0, 0, 0, 0).add(self)
  end

  def center
    Gtk::Alignment.new(0.5, 0, 0, 0).add(self)
  end

  def left
    Gtk::Alignment.new(0, 0, 0, 0).add(self)
  end

  def right
    Gtk::Alignment.new(1.0, 0, 0, 0).add(self)
  end
end

class Gtk::Container < Gtk::Widget
  def closeup(widget)
    self.pack_start(widget, false)
  end
end

class Gtk::TextBuffer < GLib::Object
  def get_range(idx, size)
    [self.get_iter_at_offset(idx), self.get_iter_at_offset(idx + size)]
  end
end

class Gtk::Clipboard
  def self.copy(t)
    Gtk::Clipboard.get(Gdk::Atom.intern('CLIPBOARD', true)).text = t
  end
end

class Gtk::Dialog
  def self.alert(message)
    Gtk::Lock.synchronize{
      dialog = Gtk::MessageDialog.new(nil,
                                      Gtk::Dialog::DESTROY_WITH_PARENT,
                                      Gtk::MessageDialog::QUESTION,
                                      Gtk::MessageDialog::BUTTONS_CLOSE,
                                      message)
      dialog.run
      dialog.destroy
    }
  end

  def self.confirm(message)
    Gtk::Lock.synchronize{
      dialog = Gtk::MessageDialog.new(nil,
                                      Gtk::Dialog::DESTROY_WITH_PARENT,
                                      Gtk::MessageDialog::QUESTION,
                                      Gtk::MessageDialog::BUTTONS_YES_NO,
                                      message)
      res = dialog.run
      dialog.destroy
      res == Gtk::Dialog::RESPONSE_YES
    }
  end
end

module GLib::SignalAdditional

  def additional_signals
    if not(@additional_signals) then
      @additional_signals = Hash.new
    end
    @additional_signals
  end

  def signal_add(signal_name)
    if additional_signals.has_key?(signal_name.to_sym) then
      raise ArgumentError.new('already exist signal '+signal_name)
    end
    additional_signals[signal_name.to_sym] = Array.new
    self
  end

  def signal_connect(detailed_signal, *other_args)
    if not(additional_signals.has_key?(detailed_signal.to_sym)) then
      return super(detailed_signal, *other_args)
    end
    additional_signals[detailed_signal.to_sym] << lambda{ |*args| yield(*args.concat(other_args)) }
    true # handler not support
  end

  def signal_emit(detailed_signal, *args)
    if not(additional_signals.has_key?(detailed_signal.to_sym)) then
      Lock.synchronize{ super(detailed_signal, *args) }
    else
      additional_signals[detailed_signal.to_sym].each{ |signal|
        if signal.call(*args) then
          break
        end
      }
    end
  end

end
