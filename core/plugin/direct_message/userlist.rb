# -*- coding: utf-8 -*-

# 最後にやりとりしたDMの日時でソートする機能のついたUserlist
module Plugin::DirectMessage
  class UserList < Gtk::UserList
    attr_accessor :dm_last_date

    def gen_order(user)
      dm_last_date[user.id] || 0 end

  end
end
