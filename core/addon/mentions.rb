
miquire :addon, 'addon'

module Addon
  class Mention < Addon

    get_all_parameter_once :mention

    def onboot(watch)
      @main = Gtk::TimeLine.new()
      self.regist_tab(@main, 'Me')
    end

    def onmention(messages)
      @main.add(messages.map{ |m| m[1] })
      @main.show_all
    end

  end
end

Plugin::Ring.push Addon::Mention.new,[:boot, :mention]
