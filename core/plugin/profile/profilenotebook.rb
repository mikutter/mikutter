# -*- coding: utf-8 -*-

UserConfig[:profile_notebook_order] ||= [:aboutuser, :usertimeline, :mylist, :directmessage]

module Gtk
  class ProfileNotebook < Gtk::Notebook
    def initialize
      @inserted_slugs = []
      super end

    # 設定された順番どおりになるようにタブを挿入する
    # ==== Args
    # [slug] ページスラッグ
    # [child] 挿入する子
    # [label] ラベルウィジェット
    # ==== Return
    # self
    def insert(slug, child, label)
      index = where_should_insert_it(slug, @inserted_slugs, UserConfig[:profile_notebook_order])
      @inserted_slugs.insert(index, slug)
      insert_page(index, child, label) end
  end
end
