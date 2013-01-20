# -*- coding: utf-8 -*-

require 'enumerator'
Plugin.create :followingcontrol do
  def open_user(user)
    Plugin.call(:show_profile, Service.primary, user) end

  def boot_event(api, service, created, destroy, followings)
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
      relations = userlist.to_a
      c = count.call
      if (c % UserConfig[retrieve_interval]) == 0
        service.__send__(api, cache: (c==0 ? true : :keep)).next{ |users|
          users = users.select(&ret_nth).reverse!.freeze
          boot_event(api, service, users - relations, relations - users, users) unless relations.empty?
          users
        }.terminate
      end } end

  def set_event(api, title)
    userlist = Gtk::UserList.new
    tab(api, title) do
      set_icon Skin.get("#{api}.png")
      expand
      nativewidget userlist
    end
    proc = gen_relationship(api, userlist)
    onperiod{ |service|
      promise = proc.call(service)
      if promise
        promise.next{ |res|
          if res
            userlist.add(res).show_all end }.terminate end }
    add_event("#{api}_created".to_sym){ |service, users|
      userlist.add(users).show_all }
    add_event("#{api}_destroy".to_sym){ |service, users|
      userlist.remove_if_exists_all(users) }
    userlist.double_clicked = method(:open_user) end

  set_event(:followings, 'Followings')
  set_event(:followers, 'Followers')

end

# Module.new do

#   def self.open_user(service)
#     lambda{ |user|
#       Plugin.call(:show_profile, service, user) } end

#   def self.boot_event(api, service, created, destroy, followings)
#     unless created.empty?
#       Plugin.call("#{api}_created".to_sym, service, created) end
#     unless destroy.empty?
#       Plugin.call("#{api}_destroy".to_sym, service, destroy) end end

#   def self.gen_relationship(api, userlist)
#     count = gen_counter
#     retrieve_interval = "retrieve_interval_#{api}".to_sym
#     retrieve_count = "retrieve_count_#{api}".to_sym
#     Plugin.create(:following_control).add_event_filter(api) { |list| [list + userlist.to_a] }
#     lambda{ |service|
#       relations = userlist.to_a
#       c = count.call
#       if (c % UserConfig[retrieve_interval]) == 0
#         service.__send__(api, cache: (c==0 ? true : :keep)).next{ |users|
#           users = users.select(&ret_nth).reverse!.freeze
#           boot_event(api, service, users - relations, relations - users, users) unless relations.empty?
#           users
#         }.terminate
#       end } end

#   def self.set_event(api, title)
#     userlist = Gtk::UserList.new.show_all
#     proc = gen_relationship(api, userlist)
#     Plugin.call(:mui_tab_regist, userlist, title, Skin.get("#{api}.png"))
#     Plugin.create(:following_control).add_event(:period){ |service|
#       promise = proc.call(service)
#       if promise
#         promise.next{ |res|
#           if res
#             userlist.add(res).show_all end }.terminate end
#     }
#     Plugin.create(:following_control).add_event("#{api}_created".to_sym){ |service, users|
#       userlist.add(users).show_all }
#     Plugin.create(:following_control).add_event("#{api}_destroy".to_sym){ |service, users|
#       userlist.remove_if_exists_all(users) }
#     userlist.double_clicked = open_user(Service.services.first) end

#   Delayer.new{
#     set_event(:followings, 'Followings')
#     set_event(:followers, 'Followers') }

# end
