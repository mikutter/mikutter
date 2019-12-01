# -*- coding: utf-8 -*-
# ユーザグループリスト用リストビュー
#

require 'mui/gtk_extension'

class Gtk::ListList < Gtk::CRUD

  def column_schemer
    [{:kind => :active, :widget => :boolean, :type => TrueClass, :label => '表示'},
     {:kind => :text, :type => String, :label => 'リスト名'},
     {:type => Diva::Model},
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
    add_hook(Service.primary, own, Plugin.filtering(:following_lists, Array.new).first, &proc)
    create = plugin.add_event(:list_created) { |service, lists|
      if destroyed?
        error "gtk widget already destroyed."
      else
        add_hook(service, own, lists, &proc) end }
    destroy = plugin.add_event(:list_destroy){ |service, list_ids|
      if destroyed?
        error "gtk widget already destroyed."
      else
        each{ |model, path, iter|
          remove(iter) if list_ids.include?(iter[2][:id]) } end }
    signal_connect(:destroy){ |w, event|
      plugin.detach(create).detach(destroy)
      true }
    self end

  private

  # リスト郡 _lists_ の中で、まだリストビューの中にないリストを追加する
  # ==== Args
  # [service] Service
  # [own] 真なら自分の作成したリストのみを追加する
  # [lists] リストの配列(Array)
  def add_hook(service, own, lists, &proc)
    (own ? lists.select{ |list| list[:user].me? } : lists).each{ |list|
      proc.call(service, list, model.append) } end

end
