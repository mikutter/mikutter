
miquire :addon, 'addon'
miquire :mui, 'skin'

Module.new do
  main = Gtk::TimeLine.new()

  plugin = Plugin::create(:friend_timeline)
  plugin.add_event(:boot){ |service|
    Plugin.call(:mui_tab_regist, main, 'Home Timeline', MUI::Skin.get("timeline.png")) }
  plugin.add_event(:update){ |service, messages|
    main.add(messages) }

end

# module Addon
#   class FriendTimeline < Addon

#     get_all_parameter_once :update

#     def onboot(watch)
#       Gtk::Lock.synchronize{
#         @main = Gtk::TimeLine.new()
#         self.regist_tab(watch, @main, 'Home Timeline', MUI::Skin.get("timeline.png"))
#       }
#     end

#     def onupdate(messages)
#       Gtk::Lock.synchronize{
#         @main.add(messages.map{ |m| m[1] })
#       }
#     end

#   end
# end

# Plugin::Ring.push Addon::FriendTimeline.new,[:boot, :update]
# ~> -:14: syntax error, unexpected '}', expecting $end
# ~> }.call
# ~>  ^
