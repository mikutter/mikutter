# -*- coding: utf-8 -*-
# mentions.rb
#
# Reply display/post support

require File.expand_path(File.join(File.basename(__FILE__), '..', 'plugin', "gui", "gui"))

Plugin.create :mentions do
  tab :mentions, "Replies" do
    set_icon Skin.get("reply.png")
    timeline :mentions end

  on_mention do |service, messages|
    timeline(:mentions) << messages end

  on_favorite do |service, fav_by, message|
    if UserConfig[:favorited_by_anyone_act_as_reply] and fav_by[:idname] != service.idname
      timeline(:mentions) << message end end
end
