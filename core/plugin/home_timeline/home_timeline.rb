# -*- coding: utf-8 -*-

Plugin.create :home_timeline do
  tab :home_timeline, "Home Timeline" do
    set_icon Skin.get("timeline.png")
    timeline :home_timeline end

  on_update do |s, ms|
    timeline(:home_timeline) << ms end
end
