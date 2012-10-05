# -*- coding: utf-8 -*-

# 最後にやりとりしたDMの日時でソートする機能のついたUserlist
module Plugin::DirectMessage
  class UserList < Gtk::UserList

    def initialize
      super
      @ul.set_sort_column_id(5, Gtk::SORT_DESCENDING)
    end

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
        iter[4] = user[:id]
        iter[5] = user[:last_dm_date]
        @users << user end end

    def modify_date(user)
      @ul.each { |model, path, iter|
        if iter[4] == user[:id]
          iter[0] = Gdk::WebImageLoader.pixbuf(user[:profile_image_url], 24, 24){ |pixbuf|
            iter[0] = pixbuf }
          iter[1] = user[:idname]
          iter[2] = user[:name]
          iter[3] = user
          iter[5] = user[:last_dm_date]
          break end }
      self end

    private

    def column_schemer
      [{:kind => :pixbuf, :type => Gdk::Pixbuf, :label => 'icon'},
       {:kind => :text, :type => String, :label => 'screen_name'},
       {:kind => :text, :type => String, :label => '名前'},
       {:type => User},
       {:type => Integer},
       {:type => Integer} ].freeze end

  end
end
