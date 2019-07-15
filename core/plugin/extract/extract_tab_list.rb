# -*- coding: utf-8 -*-
module Plugin::Extract
end

=begin rdoc
  抽出タブの一覧
=end

class Plugin::Extract::ExtractTabList < ::Gtk::TreeView
  ITER_NAME = 0
  ITER_SLUG = 1

  def initialize(plugin)
    type_strict plugin => Plugin
    @plugin = plugin
    super(Gtk::ListStore.new(String, Symbol))

    append_column Gtk::TreeViewColumn.new(plugin._("名前"), Gtk::CellRendererText.new, text: ITER_NAME)

    extract_tabs.each(&method(:add_record)) end

  # 現在選択されている抽出タブのIDを返す
  # ==== Return
  # 選択されている項目のID。何も選択されていない場合はnil
  def selected_slug
    selected_iter = selection.selected
    selected_iter[ITER_SLUG] if selected_iter end

  # レコードを追加する
  # ==== Args
  # [record] 追加するレコード(Plugin::Extract::Setting)
  # ==== Return
  # self
  def add_record(record)
    iter = model.append
    iter[Plugin::Extract::ExtractTabList::ITER_NAME] = record.name
    iter[Plugin::Extract::ExtractTabList::ITER_SLUG] = record.slug
    self
  end

  # 抽出タブをリストから削除する
  # ==== Args
  # [record_slug] 削除する抽出タブのslug
  # ==== Return
  # self
  def remove_record(record_slug)
    record_slug = record_slug.to_sym
    remove_iter = model.to_enum(:each).map{|_,_,iter|iter}.find{|iter| record_slug == iter[ITER_SLUG] }
    model.remove(remove_iter) if remove_iter
    self end

  private

# ==== utility

  # レコードの配列を返す
  # ==== Return
  # レコードの配列
  def extract_tabs
    UserConfig[:extract_tabs] || [] end

  def gen_uniq_id(uniq_id = Time.now.to_i)
    if extract_tabs.any?{ |x| x[:id] == uniq_id }
      gen_uniq_id(uniq_id + 1)
    else
      uniq_id end end

# ==== buttons


end
