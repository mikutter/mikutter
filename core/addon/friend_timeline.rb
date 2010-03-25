
miquire :addon, 'addon'

module Addon
  class FriendTimeline < Addon

    get_all_parameter_once :update

    def onboot(watch)
      @main = Gtk::TimeLine.new()
      self.regist_tab(watch, @main, 'TL')
    end

    def onupdate(messages)
      @main.add(messages.map{ |m| m[1] })
      @main.show_all
    end

  end
end

Plugin::Ring.push Addon::FriendTimeline.new,[:boot, :update]
