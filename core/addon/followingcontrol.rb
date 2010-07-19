miquire :addon, 'addon'
miquire :mui, 'skin'
miquire :mui, 'userlist'

require 'enumerator'

Module.new do
  followers_list = Gtk::UserList.new()
  followings_list = Gtk::UserList.new()

  relationship = lambda{ |api|
    count = gen_counter()
    relations = []
    lambda{ |service|
      if (count.call % UserConfig["retrieve_interval_#{api}".to_sym]) == 0
        service.method("#{api}_id").call(UserConfig["retrieve_count_#{api}".to_sym]){ |res|
          ids = res.map{ |x| x[:id] }.freeze
          users = User.findbyid(ids, -2)
          index = users.rindex(nil)
          users = service.method(api).call(index.page_of(100)) if index and index < (users.size - users.nitems)
          if not relations.empty?
            created = ids - relations
            # Plugin.call("#{api}_created".to_sym, service, created.map{ |id| User.findbyid(id, -1) }) if not created.empty?
            Plugin.call("#{api}_created".to_sym, service, User.findbyid(created, -1)) if not created.empty?
            destroy = relations - ids
            #Plugin.call("#{api}_destroy".to_sym, service, destroy.map{ |id| User.findbyid(id, -1) }) if not destroy.empty?
            Plugin.call("#{api}_destroy".to_sym, service, User.findbyid(destroy, -1)) if not destroy.empty?
          end
          relations = ids } end } }

  plugin = Plugin::create(:followers)
  plugin.add_event(:boot){ |service|
    Plugin.call(:mui_tab_regist, followings_list, 'Following', MUI::Skin.get("list.png"))
    Plugin.call(:mui_tab_regist, followers_list, 'Follower', MUI::Skin.get("list.png"))
    followers_list.double_clicked = followings_list.double_clicked = lambda{ |user|
      Plugin.call(:show_profile, service, user) }
  }
  plugin.add_event(:period, &(lambda{ |proc|
                                lambda{ |service|
                                  Thread.new{
                                    res = proc.call(service)
                                    if res
                                      users = User.findbyid(res.value, -1).select(&ret_nth).reverse
                                      Delayer.new{ followings_list.add(users).show_all } end } } }).
                   call(relationship.call(:followings)))
  plugin.add_event(:period, &(lambda{ |proc|
                                lambda{ |service|
                                  Thread.new{
                                    res = proc.call(service)
                                    if res
                                      users = User.findbyid(res.value, -1).select(&ret_nth).reverse
                                      Delayer.new{ followers_list.add(users).show_all } end } } }).
                   call(relationship.call(:followers)))
  plugin.add_event(:followings_destroy){ |service, users|
    followings_list.remove_if_exists_all(users) }
  plugin.add_event(:followers_destroy){ |service, users|
    followers_list.remove_if_exists_all(users) }

end
