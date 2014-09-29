# -*- coding: utf-8 -*-

require File.join(__dir__, 'profiletab')

Plugin.create :list_for_profile do

  profiletab :list, _("リスト") do
    set_icon Skin.get("list.png")
    container = Plugin::ListForProfile::ProfileTab.new(Plugin[:list_for_profile], user)
    nativewidget container.show_all end

end
