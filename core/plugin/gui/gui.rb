# -*- coding: utf-8 -*-
# mikutterにGUIをつけるプラグイン

require File.expand_path File.join(File.dirname(__FILE__), 'dsl')
require File.expand_path File.join(File.dirname(__FILE__), 'window')
require File.expand_path File.join(File.dirname(__FILE__), 'pane')
require File.expand_path File.join(File.dirname(__FILE__), 'tab')
require File.expand_path File.join(File.dirname(__FILE__), 'cluster')
require File.expand_path File.join(File.dirname(__FILE__), 'profiletab')
require File.expand_path File.join(File.dirname(__FILE__), 'timeline')
require File.expand_path File.join(File.dirname(__FILE__), 'tab_child_widget')
require File.expand_path File.join(File.dirname(__FILE__), 'postbox')
require File.expand_path File.join(File.dirname(__FILE__), 'command')

Plugin.create :gui do

  # タブを作成する
  # ==== Args
  # [slug] ユニークな識別名。
  # [name] タブ名。チップヘルプや、無ければアイコンに使われる。
  # [&proc] メインの定義部分
  # ==== Return
  # procの戻り値
  defdsl :tab do |slug, name=nil, &proc|
    if proc
      i_tab = Plugin::GUI::Tab.instance(slug, name, self.name)
      result = i_tab.instance_eval(&proc)
      Plugin.call :gui_tab_change_icon, i_tab
      i_tab.tab_toolbar.rewind
      result
    else
      Plugin::GUI::Tab.instance(slug, name, self.name) end end

  # _slug_ に対応するタイムラインを返す
  # ==== Args
  # [slug] タイムラインのスラッグ
  # ==== Return
  # Plugin::GUI::Timeline
  defdsl :timeline do |slug|
    Plugin::GUI::Timeline.instance(slug) end

  # プロフィールタブを定義する
  # ==== Args
  # [slug] タブスラッグ
  # [title] タブのタイトル
  defdsl :user_fragment do |slug, title, &proc|
    filter_profiletab do |tabs, i_profile, user|
      tabs.insert(where_should_insert_it(slug, tabs.map(&:first), UserConfig[:profile_tab_order]),
                  [slug,
                   -> {
                     i_profiletab = Plugin::GUI::ProfileTab.instance("#{slug}_#{user.idname}_#{Process.pid}_#{Time.now.to_i.to_s(16)}_#{rand(2 ** 32).to_s(16)}".to_sym, title)
                     i_profiletab.profile_slug = slug
                     i_profile << i_profiletab
                     i_profiletab.instance_eval{ @user = user }
                     i_profiletab.instance_eval_with_delegate(self, &proc)} ])
      [tabs, i_profile, user] end end

  # obsolete
  defdsl :profiletab do |slug, title, &proc|
    warn 'Plugin#profiletab is obsolete. use Plugin#user_fragment'
    user_fragment slug, title, &proc
  end

  # window,pane,tab設置
  Plugin::GUI.ui_setting.each { |window_slug, panes|
    window = Plugin::GUI::Window.instance(window_slug,  Environment::NAME)
    window.set_icon File.expand_path(Skin.get('icon.png'))
    window << Plugin::GUI::Postbox.instance
    if panes.empty?
      panes = { default: [] } end
    panes.each { |pane_slug, tabs|
      pane = Plugin::GUI::Pane.instance(pane_slug)
      tabs.each { |tab_slug|
        pane << Plugin::GUI::Tab.instance(tab_slug) }
      window << pane } }

  # 互換性のため。ステータスバーの更新。ツールキットプラグインで定義されているgui_window_rewindstatusを呼ぶこと
  on_rewindstatus do |text|
    Plugin.call(:gui_window_rewindstatus, Plugin::GUI::Window.instance(:default), text, 10)
  end

  on_gui_destroy do |widget|
    widget.parent.remove(widget) if widget.respond_to?(:parent)
    widget.children.each(&:destroy) if widget.respond_to?(:children) end

  filter_tabs do |set|
    [(set || {}).merge(Plugin::GUI::Tab.cuscaded)]
  end

end
