
miquire :addon, 'addon'
miquire :mui, 'skin'

module Addon
  class Mention < Addon

    get_all_parameter_once :mention

    def onboot(watch)
      Gtk::Lock.synchronize{
        @main = Gtk::TimeLine.new()
        self.regist_tab(watch, @main, 'Replies', MUI::Skin.get("reply.png"))
      }
    end

    def onmention(messages)
      Gtk::Lock.synchronize{
        @main.add(messages.map{ |m| m[1] })
      }
    end

  end
end

Plugin::Ring.push Addon::Mention.new,[:boot, :mention]
