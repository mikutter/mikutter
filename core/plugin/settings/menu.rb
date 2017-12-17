# -*- coding: utf-8 -*-
require_relative 'setting_dsl'

module Plugin::Settings
  # 設定DSLで設定された設定をリストアップし、選択するリストビュー。
  class Menu < Gtk::TreeView
    COL_LABEL = 0
    COL_RECORD = 1
    COL_ORDER = 2

    def initialize
      super(Gtk::TreeStore.new(String, Record))
      set_headers_visible(false)
      model.set_sort_column_id(COL_ORDER, Gtk::SORT_ASCENDING)
      column = Gtk::TreeViewColumn.new("", ::Gtk::CellRendererText.new, text: 0)
      self.append_column(column)
      self.set_width_request(HYDE)
      insert_defined_settings
    end

    private
    def insert_defined_settings
      record_order = UserConfig[:settings_menu_order] || ["基本設定", "入力", "表示", "通知", "ショートカットキー", "アクティビティ", "アカウント情報"]
      Plugin.filtering(:defined_settings, []).first.each do |title, definition, plugin|
        iter = model.append(nil)
        iter[COL_LABEL] = title
        iter[COL_RECORD] = Record.new(title, definition, plugin)
        iter[COL_ORDER] = (record_order.index(title) || record_order.size)
      end
    end
  end

  Record = Struct.new(:name, :proc, :plugin) do
    def widget
      box = Plugin::Settings::SettingDSL.new(Plugin.instance plugin)
      box.instance_eval(&proc)
      box
    end
  end
end
