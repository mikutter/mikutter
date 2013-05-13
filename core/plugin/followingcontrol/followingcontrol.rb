# -*- coding: utf-8 -*-

require 'enumerator'
Plugin.create :followingcontrol do

  def boot_event(api, service, created, destroy)
    type_strict api => Symbol, service => Service, created => Users, destroy => Users
    unless created.empty?
      Plugin.call("#{api}_created".to_sym, service, created) end
    unless destroy.empty?
      Plugin.call("#{api}_destroy".to_sym, service, destroy) end end

  def gen_relationship(api, userlist)
    count = gen_counter
    retrieve_interval = "retrieve_interval_#{api}".to_sym
    retrieve_count = "retrieve_count_#{api}".to_sym
    add_event_filter(api) { |list| [list + userlist.to_a] }
    lambda{ |service|
      c = count.call
      if (c % UserConfig[retrieve_interval]) == 0
        relations = userlist.to_a
        service.__send__(api, cache: (c==0 ? true : :keep)).next{ |users|
          users = Users.new(users.select(&ret_nth).reverse!).freeze
          boot_event(api, service, users - relations, relations - users) unless relations.empty?
          users
        }.terminate
      end } end

  def set_event(api, title)
    userlist = Gtk::UserList.new
    tab(api, title) do
      set_icon Skin.get("#{api}.png")
      expand
      nativewidget userlist.show_all
    end
    proc = gen_relationship(api, userlist)
    onperiod{ |service|
      promise = proc.call(service)
      if promise
        promise.next{ |res|
          if res
            userlist.add_user(res)
          end }.terminate end }
    add_event("#{api}_created".to_sym){ |service, users|
      userlist.add_user(users)
    }
    add_event("#{api}_destroy".to_sym){ |service, users|
      userlist.remove_user(users)
    }
    userlist.listview.ssc(:row_activated) { |this, path, column|
      iter = this.model.get_iter(path)
      if iter
        Plugin.call(:show_profile, Service.primary, iter[Gtk::InnerUserList::COL_USER]) end } end

  set_event(:followings, 'Followings')
  set_event(:followers, 'Followers')

end
