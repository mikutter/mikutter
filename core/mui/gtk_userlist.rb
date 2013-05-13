# -*- coding: utf-8 -*-
require 'gtk2'
miquire :mui, 'extension', 'inneruserlist'

require 'set'

class Gtk::UserList < Gtk::EventBox
  include Enumerable

  attr_reader :listview

  def initialize
    super
    @listview = Gtk::InnerUserList.new(self)
    scrollbar = ::Gtk::VScrollbar.new(@listview.vadjustment)
    add Gtk::HBox.new(false, 0).add(@listview).closeup(scrollbar)
  end

  def each
    @listview.each{ |m, p, i| i[Gtk::InnerUserList::COL_USER] } end

  def to_a
    @to_a ||= inject(Users.new, &:<<).freeze end

  # Userの配列 _users_ を追加する
  # ==== Args
  # [users] ユーザの配列
  # ==== Return
  # self
  def add_user(users)
    @to_a = nil
    @listview.add_user(users)
  end

  # Userの配列 _users_ に含まれるユーザを削除する
  # ==== Args
  # [users] ユーザの配列
  # ==== Return
  # self
  def remove_user(users)
    @to_a = nil
    @listview.remove_user(users)
  end

  def gen_order(user)
    (@order_generator ||= gen_counter).call end

  # ユーザ user の順番を再計算する
  # ==== Args
  # [user] ユーザ
  # ==== Return
  # self
  def reorder(user)
    type_strict user => User
    @listview.reorder(user)
    self end

end

