# -*- coding: utf-8 -*-

module Mainloop

  def mainloop
    @exit_flag = false
    catch(:__exit_mikutter) do
      loop do
        gtk_tick
        while not Delayer.empty?
          Delayer.run_once
          gtk_tick
        end
        sleep 0.02
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

  private

  def gtk_tick
    while Gtk.events_pending?
      Gtk.main_iteration
      throw :__exit_mikutter if @exit_flag || Gtk.exception
    end
  end

end
