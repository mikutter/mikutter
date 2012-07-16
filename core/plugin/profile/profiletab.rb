# -*- coding: utf-8 -*-

class Plugin

  # プロフィールタブを定義する
  # ==== Args
  # [slug] タブスラッグ
  # [title] タブのタイトル
  def profiletab(slug, title, &proc)
    filter_profiletab do |tabs, user|
      tabs.insert(slug, proc.call(user), Gtk::Label.new(title))
      [tabs, user]
    end
  end
end
