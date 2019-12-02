# -*- coding: utf-8 -*-
require 'mui/gtk_extension'
require 'mui/gtk_inneruserlist'

require 'gtk2'
require 'set'

class Gtk::UserList < Gtk::EventBox
  include Enumerable

  attr_reader :listview

  # ユーザをダブルクリックとかされた時に呼ばれるProcを返す
  # ==== Return
  # Proc
  def self.row_activated
    ->(this, path, column) do
      iter = this.model.get_iter(path)
      if iter
        Plugin.call(:open, iter[Gtk::InnerUserList::COL_USER])
      end
    end
  end

  def initialize
    super
    @listview = Gtk::InnerUserList.new(self)
    scrollbar = ::Gtk::VScrollbar.new(@listview.vadjustment)
    add Gtk::HBox.new(false, 0).add(@listview).closeup(scrollbar)
    @listview.ssc(:row_activated, &self.class.row_activated)
    @listview.ssc(:expose_event){
      emit_expose_user
      false
    }
  end

  def each
    @listview.each{ |m, p, i| i[Gtk::InnerUserList::COL_USER] } end

  # Userの配列 _users_ を追加する
  # ==== Args
  # [users] Enumerable ユーザを繰り返すEnumerable
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

  private

  def emit_expose_user
    if @listview.visible_range
      current, last = @listview.visible_range
      Enumerator.new{|y|
        while (current <=> last) < 1
          y << @listview.model.get_iter(current)
          break if not current.next!
        end
      }.reject{|iter|
        iter[Gtk::InnerUserList::COL_ICON]
      }.each do |iter|
        iter[Gtk::InnerUserList::COL_ICON] = iter[Gtk::InnerUserList::COL_USER].icon.load_pixbuf(width: 24, height: 24){|pixbuf|
          iter[Gtk::InnerUserList::COL_ICON] = pixbuf unless @listview.destroyed?
        }
      end
    end
  end

end

