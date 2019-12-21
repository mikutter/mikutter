# -*- coding: utf-8 -*-

module Plugin::ChangeAccount
  module WorldGenerator
    # ダイアログを生成して開く。
    # ==== Args
    # [title:] ダイアログのタイトルバーに表示する内容(String)
    # [plugin:] 呼び出し元のPluggaloid Plugin
    # ==== Return
    # 作成されたDialogのインスタンス
    def self.open(title:, plugin:)
      window = Plugin::ChangeAccount::WorldGenerator.new(plugin: plugin, title: title)
      window.show_all
      window
    end
  end
end

require_relative 'world_generator/controller'
require_relative 'world_generator/window'
