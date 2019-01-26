# -*- coding: utf-8 -*-

Plugin.create :home_timeline do
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
      tab :home_timeline, _("Home Timeline") do
        set_icon Skin[:timeline]
        timeline :home_timeline end

      on_update do |s, ms|
        timeline(:home_timeline) << ms end
    end
  end

  def absent_tab
    if @tag
      tab(:home_timeline).destroy
      detach(@tag)
      @tag = nil
    end
  end
end
