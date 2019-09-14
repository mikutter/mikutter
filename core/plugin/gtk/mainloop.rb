# -*- coding: utf-8 -*-

module Mainloop

  TICK_MAX = 20
  TICK_MIN = 2

  def mainloop
    @exit_flag = false
    catch(:__exit_mikutter) do
      tick = TICK_MAX
      loop do
        if tick > TICK_MIN
          tick -= 1
        end
        if Gtk.events_pending?
          tick = TICK_MAX + 1
          Gtk.main_iteration
          throw :__exit_mikutter if @exit_flag || Gtk.exception
        end
        unless Delayer.empty?
          tick = TICK_MAX + 1
          Delayer.run_once
          throw :__exit_mikutter if @exit_flag || Gtk.exception
        end
        sleep(1.0 / tick) if tick <= TICK_MAX
      end
    end
  rescue Interrupt,SystemExit,SignalException => exception
    raise exception
  rescue Exception => exception
    Gtk.exception = exception
  ensure
    SerialThreadGroup.force_exit!
  end

  def exception_filter(e)
    Gtk.exception ? Gtk.exception : e
  end

  def reserve_exit
    @exit_flag = true
  end

  def exit!
    throw(:__exit_mikutter)
  end
end
