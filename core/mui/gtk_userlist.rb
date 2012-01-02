# -*- coding: utf-8 -*-
require 'gtk2'
miquire :mui, 'extension'
miquire :core, 'user'
miquire :mui, 'icon_over_button'

require 'set'

#
# TODO: timelineからコピペで作ったからリファクタリングしてモジュールを作る
#

module Gtk
  class UserList < Gtk::HBox
    include Enumerable

    attr_accessor :double_clicked

    def initialize()
      @users = Set.new
      @double_clicked = ret_nth
      super()
      @evbox, @ul, @treeview = gen_userlist
      scrollbar = Gtk::VScrollbar.new(@treeview.vadjustment)
      pack_start(@evbox).closeup(scrollbar).show_all
    end

    # Userクラスのインスタンスを引数に繰り返すイテレータ
    def each(&iter) # :yields: user
      @users.each(&iter)
    end

    # リストに _user_ を追加する。既にある場合は何もしない。
    # ==== Args
    # - user Userのインスタンスか、Userの配列(Enumerable)
    # ==== Return
    # _self_
    def add(user)
      if user.is_a?(Array) then
        self.block_add_all(user)
      else
        self.block_add(user) end
      self.show_all end

    # リストに _user) を追加する
    # ==== Args
    # - Object user
    # ==== Return
    # _self_
    def block_add(user)
      if user[:rule] == :destroy
        remove_if_exists_all([user])
      elsif not @users.include?(user)
        iter = @ul.prepend
        iter[0] = Gdk::WebImageLoader.pixbuf(user[:profile_image_url], 24, 24){ |pixbuf|
          iter[0] = pixbuf }
        iter[1] = user[:idname]
        iter[2] = user[:name]
        iter[3] = user
        @users << user end end

    # Userの配列を受け取って、それら全てを追加する
    # ==== Args
    # - Object users
    # ==== Return
    # _self_
    def block_add_all(users)
      removes, appends = *users.partition{ |m| m[:rule] == :destroy }
      remove_if_exists_all(removes)
      appends.each(&method(:block_add))
    end

    # Userの配列を受け取って、リストに入っているユーザは削除する
    # ==== Args
    # - Object users
    # ==== Return
    # _self_
    def remove_if_exists_all(users)
      if defined? @ul
        users_idname = users.map{ |user| user[:idname] }.freeze
        @ul.each{ |model, path, iter|
          remove_user_name = iter[1].to_s
          if users_idname.include?(remove_user_name)
            @ul.remove(iter)
            @users.delete_if{ |user| user[:idname] == remove_user_name } end } end
      self end

    # リストに入っているユーザのIDを配列にして返す
    # ==== Return
    # リスト内のUserのidの配列
    def all_id
      if defined? @ul
        @users.map{ |x| x[:id].to_i }
      else
        [] end end

    # リスト内のユーザを全て削除する
    # ==== Return
    # _self_
    def clear
      if defined? @treeview
          @treeview.clear
          @users.clear end
      self end

    private

    def gen_userlist
      container = Gtk::EventBox.new
      treeview = View.new(column_schemer)
      box = treeview.model

      treeview.signal_connect("row-activated") do |view, path, column|
        if iter = view.model.get_iter(path)
          double_clicked.call(iter[3]) end end

      container.add(treeview)

      style = Gtk::Style.new()
      style.set_bg(Gtk::STATE_NORMAL, *[255,255,255].map{|a| a*255})
      container.style = style

      treeview.ssc(:scroll_event){ |this, e|
        case e.direction
        when Gdk::EventScroll::UP
          this.vadjustment.value -= this.vadjustment.step_increment
        when Gdk::EventScroll::DOWN
          this.vadjustment.value += this.vadjustment.step_increment end
        false }
      return container, box, treeview end

      def column_schemer
        [{:kind => :pixbuf, :type => Gdk::Pixbuf, :label => 'icon'},
         {:kind => :text, :type => String, :label => 'screen_name'},
         {:kind => :text, :type => String, :label => '名前'},
         {:type => User} ].freeze end

    class View < Gtk::CRUD
      C_ICON = 0
      C_TEXT = 1
      C_RAW = 2

      def initialize(column_schemer)
        @column_schemer = column_schemer
        super()
        @creatable = @updatable = @deletable = false
      end

      private

      attr_reader :column_schemer
    end

  end
end
# ~> -:3: undefined method `miquire' for main:Object (NoMethodError)
