# -*- coding: utf-8 -*-

require 'gtk2'
miquire :mui, 'extension'

class Gtk::InnerUserList < Gtk::TreeView
  include Gtk::TreeViewPrettyScroll
  COL_ICON = 0
  COL_SCREEN_NAME = 1
  COL_NAME = 2
  COL_USER = 3
  COL_ORDER = 4

  def initialize(userlist)
    @userlist = userlist
    super(::Gtk::ListStore.new(Gdk::Pixbuf, String, String, Object, Integer))
    append_column ::Gtk::TreeViewColumn.new("", ::Gtk::CellRendererPixbuf.new, pixbuf: COL_ICON)
    append_column ::Gtk::TreeViewColumn.new("SN", ::Gtk::CellRendererText.new, text: COL_SCREEN_NAME)
    append_column ::Gtk::TreeViewColumn.new("名前", ::Gtk::CellRendererText.new, text: COL_NAME)
    model.set_sort_column_id(COL_ORDER,  Gtk::SORT_DESCENDING)
  end

  # Userの配列 _users_ を追加する
  # ==== Args
  # [users] ユーザの配列
  # ==== Return
  # self
  def add_user(users)
    type_strict users => Users
    (users - Enumerator.new(model).map{ |model,path,iter| iter[COL_USER] }).each { |user|
      iter = model.append
      iter[COL_ICON] = Gdk::WebImageLoader.pixbuf(user[:profile_image_url], 24, 24){ |pixbuf|
        if not destroyed?
          iter[COL_ICON] = pixbuf end }
      iter[COL_SCREEN_NAME] = user[:idname]
      iter[COL_NAME] = user[:name]
      iter[COL_USER] = user
      iter[COL_ORDER] = @userlist.gen_order(user) }
    self end

  # Userの配列 _users_ に含まれるユーザを削除する
  # ==== Args
  # [users] ユーザの配列
  # ==== Return
  # self
  def remove_user(users)
    type_strict users => Users
    model.select{ |model,path,iter|
      users.include?(iter[COL_USER])
    }.each &model.method(:remove)
    self end

  # ユーザ user の順番を再計算する
  # ==== Args
  # [user] ユーザ
  # ==== Return
  # self
  def reorder(user)
    type_strict user => User
    each{ |m, p, iter|
      if iter[COL_USER] == user
        iter[COL_ORDER] = @userlist.gen_order(user)
        return self end }
    self end
end








