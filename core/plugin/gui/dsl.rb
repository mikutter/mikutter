# -*- coding: utf-8 -*-
# GUI定義用のDSLを宣言する

class Plugin
  module GUI
    Event = Struct.new(:event, :widget, :messages)
    class << self
      def ui_setting
        {                           # windows
          default: {                # panes
            default: [ :home_timeline ] # tabs
          }
        }
      end

      # 設定されているタブの位置を返す
      # ==== Args
      # [find_slug] タブのスラッグ
      # ==== Return
      # [ウィンドウスラッグ, ペインスラッグ, タブのインデックス] の配列。
      # 見つからない場合はnil
      def get_tab_order(find_slug)
        ui_setting.each{ |window_slug, panes|
          panes.each{ |pane_slug, tabs|
            tabs.each_with_index{ |tab_slug, index|
              return [window_slug, pane_slug, index] if tab_slug == find_slug } } }
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
  def tab(slug, name, &proc)
    Plugin::GUI::Tab.instance(slug, name).instance_eval(&proc) end

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
      i_profile << i_profiletab
      i_profiletab.instance_eval{ @user = user }
      i_profiletab.instance_eval(&proc) end
  end
end
