# -*- coding: utf-8 -*-
# ユーザグループリスト用リストビュー
#

miquire :mui, 'extension'

class Gtk::ListList < Gtk::ScrolledWindow
  attr_reader :model, :view

  # proc(iter) ... check box clicked callback
  #            ... iter=[bool toggled, String label, Object optional]
  def initialize(&proc)
    super
    @model = Gtk::ListStore.new(TrueClass, String, Object)
    @view = Gtk::TreeView.new(@model)
    add_with_viewport(@view).show_all
    toggled = Gtk::CellRendererToggle.new
    toggled.signal_connect('toggled'){ |toggled, path|
      iter = @model.get_iter(path)
      proc.call(iter) }
    col = Gtk::TreeViewColumn.new('表示', toggled, :active => 0)
    col.resizable = false
    @view.append_column(col)

    col = Gtk::TreeViewColumn.new('リスト名', Gtk::CellRendererText.new, :text => 1)
    col.resizable = true
    @view.append_column(col)
    @view.set_enable_search(true).set_search_column(1).set_search_equal_func{ |model, columnm, key, iter|
      not iter[columnm].include?(key) }
  end

  # 「自分」のアカウントが関係するTwitterリストでこのリストビューを埋める。
  # ==== Args
  # [own]
  #   真なら自分が作成したTwitterリストのみをこのリストビューに入れる
  #   偽なら自分が作成したものと自分がフォローしているTwitterリストも入れる
  # ==== Return
  # self
  def set_auto_get(own = false, &proc)
    plugin = Plugin::create(:listlist)
    create = plugin.add_event :list_create, &plugin.fetch_event(:list_data){ |service, lists|
      lists = lists.select{ |list| list[:user].is_me? } if own
      lists.each{ |list|
        iter = @model.append
        iter[0] = proc.call(list)
        iter[1] = list['full_name']
        iter[2] = list } }
    destroy = plugin.add_event(:list_destroy){ |service, list_ids|
      unless @view.destroyed?
        @view.each{ |model, path, iter|
          @view.remove(iter) if list_ids.include?(iter[2]['id']) } end }
    @view.signal_connect('destroy-event'){ |w, event|
      plugin.detach(create).detach(destroy) }
    self end
end
