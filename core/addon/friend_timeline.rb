
miquire :addon, 'addon'
miquire :mui, 'skin'

module Addon
  class FriendTimeline < Addon

    get_all_parameter_once :update

    def onboot(watch)
      Gtk::Lock.synchronize{
        @main = Gtk::TimeLine.new()
        self.regist_tab(watch, @main, 'TL', MUI::Skin.get("timeline.png"))
      }
    end

    def onupdate(messages)
      Gtk::Lock.synchronize{
        @main.add(messages.map{ |m| m[1] })
      }
    end

  end
end

Plugin::Ring.push Addon::FriendTimeline.new,[:boot, :update]
