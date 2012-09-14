# -*- coding: utf-8 -*-
# ユーザグループリスト用リストビュー
#

miquire :mui, 'extension'

class Gtk::ListList < Gtk::CRUD

  def column_schemer
    [{:kind => :active, :widget => :boolean, :type => TrueClass, :label => '表示'},
     {:kind => :text, :type => String, :label => 'リスト名'},
     {:type => Object},
    ].freeze
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
