# -*- coding: utf-8 -*-
# mikutterにGUIをつけるプラグイン

require File.expand_path File.join(File.dirname(__FILE__), 'dsl')
require File.expand_path File.join(File.dirname(__FILE__), 'window')
require File.expand_path File.join(File.dirname(__FILE__), 'pane')
require File.expand_path File.join(File.dirname(__FILE__), 'tab')
require File.expand_path File.join(File.dirname(__FILE__), 'timeline')
require File.expand_path File.join(File.dirname(__FILE__), 'command')

Plugin.create :gui do

  Plugin::GUI.ui_setting.each { |window_slug, panes|
    window = Plugin::GUI::Window.instance(window_slug)
    window << Plugin::GUI::Postbox.instance
    panes.each { |pane_slug, tabs|
      pane = Plugin::GUI::Pane.instance(pane_slug)
      window << pane
    }
  }

  # 互換性のため。ステータスバーの更新。gtk等ツールキットプラグインで定義されているgui_window_rewindstatusを呼ぶこと
  on_rewindstatus do |text|
    Plugin.call(:gui_window_rewindstatus, Plugin::GUI::Window.instance(:default), text, 60)
  end

  api_limit = {:ip_remain => '-', :ip_time => '-', :auth_remain => '-', :auth_time => '-'}

  on_apiremain do |remain, time|
    api_limit[:auth_remain] = remain
    api_limit[:auth_time] = time.strftime('%H:%M')
    Plugin.call(:gui_window_rewindstatus, Plugin::GUI::Window.instance(:default), "API auth#{api_limit[:auth_remain]}回くらい (#{api_limit[:auth_time]}まで) IP#{api_limit[:ip_remain]}回くらい (#{api_limit[:ip_time]}まで)", 60)
  end

  on_ipremain do |remain, time|
    api_limit[:ip_remain] = remain
    api_limit[:ip_time] = time.strftime('%H:%M')
    Plugin.call(:gui_window_rewindstatus, Plugin::GUI::Window.instance(:default), "API auth#{api_limit[:auth_remain]}回くらい (#{api_limit[:auth_time]}まで) IP#{api_limit[:ip_remain]}回くらい (#{api_limit[:ip_time]}まで)", 60)
  end

  on_gui_destroy do |widget|
    if widget.respond_to?(:parent)
      notice "destroy " + widget.to_s
      widget.parent.remove(widget) end end

  filter_tabs do |set|
    [(set || {}).merge(Plugin::GUI::Tab.cuscaded)]
  end

end
