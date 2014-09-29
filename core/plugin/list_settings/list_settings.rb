# -*- coding: utf-8 -*-
require File.join(__dir__, 'tab')

require 'gtk2'

Plugin.create :list_settings do
  this = self

  settings _("リスト") do
    pack_start(this.setting_container, true)
  end

  # 設定のGtkウィジェット
  def setting_container
    tab = Plugin::ListSettings::Tab.new(self)
    available_lists.each{ |list|
      iter = tab.model.append
      iter[Plugin::ListSettings::Tab::SLUG] = list[:full_name]
      iter[Plugin::ListSettings::Tab::LIST] = list
      iter[Plugin::ListSettings::Tab::NAME] = list[:name]
      iter[Plugin::ListSettings::Tab::DESCRIPTION] = list[:description]
      iter[Plugin::ListSettings::Tab::PUBLICITY] = list[:mode] }
    Gtk::HBox.new.add(tab).closeup(tab.buttons(Gtk::VBox)).show_all end

  # フォローしているリストを返す
  def available_lists
    Plugin.filtering(:following_lists, []).first
  end

end
