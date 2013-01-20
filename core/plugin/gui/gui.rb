# -*- coding: utf-8 -*-
# mikutterにGUIをつけるプラグイン

require File.expand_path File.join(File.dirname(__FILE__), 'dsl')
require File.expand_path File.join(File.dirname(__FILE__), 'window')
require File.expand_path File.join(File.dirname(__FILE__), 'pane')
require File.expand_path File.join(File.dirname(__FILE__), 'tab')
require File.expand_path File.join(File.dirname(__FILE__), 'profile')
require File.expand_path File.join(File.dirname(__FILE__), 'profiletab')
require File.expand_path File.join(File.dirname(__FILE__), 'timeline')
require File.expand_path File.join(File.dirname(__FILE__), 'tab_child_widget')
require File.expand_path File.join(File.dirname(__FILE__), 'postbox')
require File.expand_path File.join(File.dirname(__FILE__), 'command')

Plugin.create :gui do

  Plugin::GUI.ui_setting.each { |window_slug, panes|
    window = Plugin::GUI::Window.instance(window_slug,  Environment::NAME)
    window.set_icon File.expand_path(Skin.get('icon.png'))
    window << Plugin::GUI::Postbox.instance
    if panes.empty?
      panes = { default: [] } end
    panes.each { |pane_slug, tabs|
      pane = Plugin::GUI::Pane.instance(pane_slug)
      window << pane
    }
  }

  # 互換性のため。ステータスバーの更新。ツールキットプラグインで定義されているgui_window_rewindstatusを呼ぶこと
  on_rewindstatus do |text|
    Plugin.call(:gui_window_rewindstatus, Plugin::GUI::Window.instance(:default), text, 10)
  end

  on_gui_destroy do |widget|
    if widget.respond_to?(:parent)
      notice "destroy " + widget.to_s
      widget.parent.remove(widget) end end

  filter_tabs do |set|
    [(set || {}).merge(Plugin::GUI::Tab.cuscaded)]
  end

end
