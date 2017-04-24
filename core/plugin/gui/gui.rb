# -*- coding: utf-8 -*-
# mikutterにGUIをつけるプラグイン

require File.expand_path File.join(File.dirname(__FILE__), 'dsl')
require File.expand_path File.join(File.dirname(__FILE__), 'window')
require File.expand_path File.join(File.dirname(__FILE__), 'pane')
require File.expand_path File.join(File.dirname(__FILE__), 'tab')
require File.expand_path File.join(File.dirname(__FILE__), 'cluster')
require File.expand_path File.join(File.dirname(__FILE__), 'fragment')
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
  defdsl :timeline do |slug, &proc|
    tl = Plugin::GUI::Timeline.instance(slug)
    tl.instance_eval(&proc) if proc
    tl end

  # プロフィールタブを定義する
  # ==== Args
  # [slug] タブスラッグ
  # [title] タブのタイトル
  defdsl :user_fragment do |slug, title, &proc|
    filter_user_detail_view_fragments do |tabs, i_cluster, user|
      tabs.insert(where_should_insert_it(slug, tabs.map(&:first), UserConfig[:profile_tab_order]),
                  [slug,
                   -> {
                     fragment_slug = "#{slug}_#{user.uri}_#{Process.pid}_#{Time.now.to_i.to_s(16)}_#{rand(2 ** 32).to_s(16)}".to_sym
                     i_fragment = Plugin::GUI::Fragment.instance(fragment_slug, title)
                     i_cluster << i_fragment
                     i_fragment.instance_eval{ @model = user }
                     handler_tag(fragment_slug) do |tag|
                       on_gui_destroy do |w|
                         detach(tag) if w == i_fragment end
                       i_fragment.instance_eval_with_delegate(self, &proc) end } ])
      [tabs, i_cluster, user] end end

  # 投稿詳細タブを定義する
  # ==== Args
  # [slug] タブスラッグ
  # [title] タブのタイトル
  defdsl :message_fragment do |slug, title, &proc|
    filter_message_detail_view_fragments do |tabs, i_cluster, message|
      tabs.insert(where_should_insert_it(slug, tabs.map(&:first), UserConfig[:profile_tab_order]),
                  [slug,
                   -> {
                     fragment_slug = "#{slug}_#{message.uri}_#{Process.pid}_#{Time.now.to_i.to_s(16)}_#{rand(2 ** 32).to_s(16)}".to_sym
                     i_fragment = Plugin::GUI::Fragment.instance(fragment_slug, title)
                     i_cluster << i_fragment
                     i_fragment.instance_eval{ @model = message }
                     handler_tag(fragment_slug) do |tag|
                       on_gui_destroy do |w|
                         detach(tag) if w == i_fragment end
                       i_fragment.instance_eval_with_delegate(self, &proc) end } ])
      [tabs, i_cluster, message] end end

  # ダイアログボックスを作成し表示する。
  # ダイアログボックスの内容は _proc_ によって生成される。
  # _proc_ からは、 _Gtk::FormDSL_ のメソッドを利用して内容を作成できる。
  # ==== Args
  # [title] ダイアログボックスタイトルバー等に表示されるテキスト(String)
  # ==== Return
  # 入力の完了・中断を通知する _Delayer::Deferred_ 。
  # OKボタンが押された場合は _next_ が、キャンセルが押されたり、ボタンを押さずにダイアログを閉じた場合は _trap_ が呼ばれる。
  # ブロックに渡されるオブジェクトは:
  # ===== OKボタンが押された場合
  #     obj.ok? # => true
  #     obj.state # => :ok
  #     obj[:'フォームエレメントのキー(Symbol)'] # => フォームに入力されている値
  #     obj.to_h # => {フォームエレメントのキー: フォームに入力されている値} のHash
  # ===== キャンセルボタンが押された場合
  #     obj.ok? # => false
  #     obj.state # => :cancel
  # ===== ボタンを押さずにダイアログを閉じられた場合
  #     obj.ok? # => false
  #     obj.state # => :close
  defdsl :dialog do |title, &proc|
    promise = Delayer::Deferred.new(true)
    Plugin.call(:gui_dialog, self, title, proc, promise)
    promise
  end

  # obsolete
  defdsl :profiletab do |slug, title, &proc|
    warn 'Plugin#profiletab is obsolete. use Plugin#user_fragment'
    user_fragment slug, title, &proc
  end

  # window,pane,tab設置
  Plugin::GUI.ui_setting.each { |window_slug, panes|
    window = Plugin::GUI::Window.instance(window_slug,  Environment::NAME)
    window.set_icon Skin['icon.png']
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
