# -*- coding: utf-8 -*-
# ユーザグループリスト用リストビュー
#

miquire :mui, 'extension'

class Gtk::ListList < Gtk::CRUD

  def column_schemer
    [{:kind => :active, :widget => :boolean, :type => TrueClass, :label => '表示'},
     {:kind => :text, :type => String, :label => 'リスト名'},
     {:type => UserList},
    ].freeze
  end

  # 「自分」のアカウントが関係するTwitterリストでこのリストビューを埋める。
  # ==== Args
  # [own]
  #   真なら自分が作成したTwitterリストのみをこのリストビューに入れる
  #   偽なら自分が作成したものと自分がフォローしているTwitterリストも入れる
  # ==== Return
  # self
  def set_auto_getter(plugin, own = false, &proc)
    type_strict plugin => Plugin, proc => Proc
    add_hook(Service.primary, own, UserLists.new(Plugin.filtering(:following_lists, UserLists.new).first), &proc)
    create = plugin.add_event(:list_created) { |service, lists|
      add_hook(service, own, lists, &proc) }
    destroy = plugin.add_event(:list_destroy){ |service, list_ids|
      unless destroyed?
        each{ |model, path, iter|
          remove(iter) if list_ids.include?(iter[2][:id]) } end }
    signal_connect('destroy-event'){ |w, event|
      plugin.detach(create).detach(destroy) }
    self end

  private

  # リスト郡 _lists_ の中で、まだリストビューの中にないリストを追加する
  # ==== Args
  # [service] Service
  # [own] 真なら自分の作成したリストのみを追加する
  # [lists] リストの配列(UserLists)
  def add_hook(service, own, lists, &proc)
    type_strict service => Service, lists => UserLists, proc => Proc
    (own ? lists.select{ |list| list[:user].is_me? } : lists).each{ |list|
      proc.call(service, list, model.append) } end

end
