miquire :core, 'utils'

require 'gtk2'
require 'monitor'

class Gtk::Lock

  @@monitor = Monitor.new

  def self.synchronize
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
