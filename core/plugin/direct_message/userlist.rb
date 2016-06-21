# -*- coding: utf-8 -*-

# 最後にやりとりしたDMの日時でソートする機能のついたUserlist
module Plugin::DirectMessage
  class UserList < Gtk::UserList
    def initialize
      super
      @dm_last_date = Hash.new
    end

    def gen_order(user)
      @dm_last_date[user.id] || 0 end

    def update(update_hash)
      update_hash.each do |user, last_date|
        @dm_last_date[user[:id]] = last_date.to_i
      end
      add_user(Users.new(update_hash.keys))
    end
  end
end
