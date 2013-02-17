# -*- coding: utf-8 -*-
# GUI定義用のDSLを宣言する

module Plugin::GUI
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
