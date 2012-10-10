# -*- coding: utf-8 -*-
# GUI定義用のDSLを宣言する

class Plugin
  module GUI
    Event = Struct.new(:event, :widget, :messages)
    class << self
      def ui_setting
        UserConfig[:ui_tab_order] || {default: {default: [:home_timeline, :mentions, :アクティビティ, :directmessage, :search, :Followings, :Followers]}} end

      # 設定されているタブの位置を返す
      # ==== Args
      # [find_slug] タブのスラッグ
      # ==== Return
      # [ウィンドウスラッグ, ペインスラッグ, タブのインデックス] の配列。
      # 見つからない場合はnil
      def get_tab_order(find_slug)
        ui_setting.each{ |window_slug, panes|
          panes.each{ |pane_slug, tabs|
            return [window_slug, pane_slug, tabs] if tabs.include?(find_slug) } }
        nil end

      # キー _key_ がウィジェット _widget_ の上で押された時に呼び出す
      # ==== Args
      # [key] 押されたキーの名前
      # [widget] キーが押されたウィジェット
      # ==== Return
      # 何かmikutterコマンドが実行されたなら真
      def keypress(key, widget)
        result = Plugin.filtering(:keypress, key, widget, false)
        result && result.last end

    end
  end

  # タブを作成する
  # ==== Args
  # [slug] ユニークな識別名。
  # [name] タブ名。チップヘルプや、無ければアイコンに使われる。
  # [&proc] メインの定義部分
  # ==== Return
  # procの戻り値
  def tab(slug, name=nil, &proc)
    if proc
      Plugin::GUI::Tab.instance(slug, name, self.name).instance_eval(&proc)
    else
      Plugin::GUI::Tab.instance(slug, name, self.name) end end

  # _slug_ に対応するタイムラインを返す
  # ==== Args
  # [slug] タイムラインのスラッグ
  # ==== Return
  # Plugin::GUI::Timeline
  def timeline(slug)
    Plugin::GUI::Timeline.instance(slug) end

  # プロフィールタブを定義する
  # ==== Args
  # [slug] タブスラッグ
  # [title] タブのタイトル
  def profiletab(slug, title, &proc)
    on_profiletab do |i_profile, user|
      i_profiletab = Plugin::GUI::ProfileTab.instance("#{slug}_#{user.idname}_#{Process.pid}_#{Time.now.to_i.to_s(16)}_#{rand(2 ** 32).to_s(16)}".to_sym, title)
      i_profiletab.profile_slug = slug
      i_profile.add_child(i_profiletab, where_should_insert_it(slug, i_profile.children.map(&:profile_slug), UserConfig[:profile_tab_order]))
      i_profiletab.instance_eval{ @user = user }
      i_profiletab.instance_eval(&proc) end
  end
end
