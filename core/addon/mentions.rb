# mentions.rb
#
# Reply display/post support

miquire :addon, 'addon'
miquire :mui, 'skin'
miquire :mui, 'timeline'

module Addon
  class Mention < Addon

    get_all_parameter_once :mention

    def onboot(watch)
      Gtk::Lock.synchronize{
        @main = Gtk::TimeLine.new()
        self.regist_tab(watch, @main, 'Replies', MUI::Skin.get("reply.png"))
        after_replymark_icon
      }
    end

    def onmention(messages)
      Gtk::Lock.synchronize{
        @main.add(messages.map{ |m| m[1] })
      }
    end

    def after_replymark_icon
      Gtk::TimeLine.addwidgetrule(/@([a-zA-Z0-9_]+)/){ |text|
        user = User.selectby(:idname, text[1, text.size], -2).first
        Gtk::WebIcon.new(user[:profile_image_url], 12, 12) if user } end
  end
end

Plugin::Ring.push Addon::Mention.new,[:boot, :mention]
