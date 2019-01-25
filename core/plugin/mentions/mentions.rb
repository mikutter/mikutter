# -*- coding: utf-8 -*-
# mentions.rb
#
# Reply display/post support

Plugin.create :mentions do
  Delayer.new do
    refresh_tab
  end

  on_world_after_created do |world|
    refresh_tab
  end

  on_world_destroy do |world|
    refresh_tab
  end

  def refresh_tab
    if Enumerator.new{|y| Plugin.filtering(:worlds, y) }.any?{|w| w.class.slug == :twitter }
      present_tab
    else
      absent_tab
    end
  end

  def present_tab
    @tag ||= handler_tag do
      tab :mentions, _("Replies") do
        set_icon Skin[:reply]
        timeline :mentions
      end

      on_mention do |service, messages|
        timeline(:mentions) << messages
      end

      on_favorite do |service, fav_by, message|
        if UserConfig[:favorited_by_anyone_act_as_reply] and fav_by.respond_to?(:idname) and service.respond_to?(:idname) and fav_by.idname != service.idname
          timeline(:mentions) << message
        end
      end
    end
  end

  def absent_tab
    if @tag
      tab(:mentions).destroy
      detach(@tag)
      @tag = nil
    end
  end
end
