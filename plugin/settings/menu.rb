# -*- coding: utf-8 -*-
require_relative 'setting_dsl'
require_relative 'phantom'

module Plugin::Settings
  # 設定DSLで設定された設定をリストアップし、選択するリストビュー。
  class Menu < Gtk::TreeView
    COL_LABEL = 0
    COL_RECORD = 1
    COL_ORDER = 2

    def initialize
      super(Gtk::TreeStore.new(String, Record, Integer))
      set_headers_visible(false)
      model.set_sort_column_id(COL_ORDER, Gtk::SORT_ASCENDING)
      column = Gtk::TreeViewColumn.new("", ::Gtk::CellRendererText.new, text: 0)
      self.append_column(column)
      self.set_width_request(HYDE)
      insert_defined_settings
    end

    private
    def record_order
      UserConfig[:settings_menu_order] || ["基本設定", "入力", "表示", "通知", "ショートカットキー", "アクティビティ", "アカウント情報"]
    end

    def insert_defined_settings
      Plugin.filtering(:defined_settings, []).first.each do |title, definition, plugin|
        add_record(Record.new(title, definition, plugin))
      end
    end

    def add_record(record, parent: nil)
      iter = model.append(parent)
      iter[COL_LABEL] = record.name
      iter[COL_RECORD] = record
      iter[COL_ORDER] = (record_order.index(record.name) || record_order.size)
      Delayer.new do
        next if destroyed?
        record.children.deach do |child_record|
          break if destroyed?
          add_record(child_record, parent: iter)
        end
      end
    end
  end

  class Record
    extend Memoist

    attr_reader :name

    def initialize(name, proc, plugin, ancestor_advice: nil)
      @name = name
      @proc = proc
      @plugin = plugin
      @ancestor_advice = ancestor_advice
    end

    def widget
      box = Plugin::Settings::SettingDSL.new(Plugin.instance(@plugin))
      box.instance_eval(&@proc)
      box
    end

    def children
      @ancestor_advice ||= Phantom.new(@plugin, &@proc).detected
    end

    def inspect
      "#<#{self.class}: #{name.inspect} plugin: #{plugin.inspect} #{proc.inspect}>"
    end
  end
end
