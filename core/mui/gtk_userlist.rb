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
      @block_add = method(:block_add).to_proc
      super()
    end

    def userlist
      if defined? @ul
        yield
      else
        @evbox, @ul, @treeview = gen_userlist
        yield
        scrollbar = Gtk::VScrollbar.new(@treeview.vadjustment)
        pack_start(@evbox).closeup(scrollbar).show_all
      end end

    def each(&iter)
      @users.each(&iter)
    end

    def add(user)
      userlist{
        if user.is_a?(Array) then
          self.block_add_all(user)
        else
          self.block_add(user) end }
      self.show_all end

    def block_add(user)
      Lock.synchronize do
        if user[:rule] == :destroy
          remove_if_exists_all([user])
        elsif not @users.include?(user)
          iter = @ul.prepend
          iter[0] = Gtk::WebIcon.get_icon_pixbuf(user[:profile_image_url], 24, 24){ |pixbuf|
            iter[0] = pixbuf }
          iter[1] = user[:idname]
          iter[2] = user[:name]
          iter[3] = user
          @users << user end end end

    def block_add_all(users)
      Lock.synchronize do
        removes, appends = *users.partition{ |m| m[:rule] == :destroy }
        remove_if_exists_all(removes)
        appends.each(&@block_add)
      end
    end

    def remove_if_exists_all(users)
      if defined? @ul
        Lock.synchronize do
          users_idname = users.map{ |user| user[:idname] }.freeze
          @ul.each{ |model, path, iter|
            remove_user_name = iter[1].to_s
            if users_idname.include?(remove_user_name)
              @ul.remove(iter)
              @users.delete_if{ |user| user[:idname] == remove_user_name }
            end }
          end end
      self end

    def all_id
      if defined? @ul
        @users.map{ |x| x[:id].to_i }
      else
        [] end end

    def clear
      if defined? @treeview
        Lock.synchronize do
          @treeview.clear
          @users.clear end end
      self end

    def gen_userlist
      Lock.synchronize do
        container = Gtk::EventBox.new
        box = Gtk::ListStore.new(Gdk::Pixbuf, String, String, User)
        treeview = Gtk::TreeView.new(box)
        crText = Gtk::CellRendererText.new
        col = Gtk::TreeViewColumn.new 'icon', Gtk::CellRendererPixbuf.new, :pixbuf => 0
        col.resizable = true
        treeview.append_column col

        col = Gtk::TreeViewColumn.new 'ユーザID', Gtk::CellRendererText.new, :text => 1
        col.resizable = true
        treeview.append_column col

        col = Gtk::TreeViewColumn.new '名前', Gtk::CellRendererText.new, :text => 2
        col.resizable = true
        treeview.append_column col

        treeview.set_enable_search(true).set_search_column(1).set_search_equal_func{ |model, columnm, key, iter|
          not iter[columnm].include?(key) }

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
        return container, box, treeview end end
  end
end
# ~> -:3: undefined method `miquire' for main:Object (NoMethodError)
