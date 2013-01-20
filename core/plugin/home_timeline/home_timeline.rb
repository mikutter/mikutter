# -*- coding: utf-8 -*-

require File.expand_path(File.join(File.basename(__FILE__), '..', 'plugin', "gui", "gui"))

Plugin.create :home_timeline do
  tab :home_timeline, "Home Timeline" do
    set_icon Skin.get("timeline.png")
    timeline :home_timeline end

  on_update do |s, ms|
    timeline(:home_timeline) << ms end
end
