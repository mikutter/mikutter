# -*- coding: utf-8 -*-

Plugin.create :display_requirements do
  # command(:fucking_bird,
  #         name: 'Twitter.comへ',
  #         condition: lambda{ |opt| true },
  #         visible: true,
  #         icon: MUI::Skin.get("twitter-bird.png"),
  #         role: :tab) do |opt|
  #   Gtk::openurl("http://twitter.com/")
  # end

  on_gui_timeline_join_tab do |i_timeline, i_tab|
    i_tab.shrink
    i_tab.nativewidget(Gtk::WebIcon.new(MUI::Skin.get("twitter-bird.png"), 32, 32))
    i_tab.expand
  end

end
