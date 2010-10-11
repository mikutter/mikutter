miquire :addon, 'addon'
miquire :mui, 'skin'
miquire :mui, 'userlist'

require 'enumerator'

Module.new do

  def self.open_user(service)
    lambda{ |user|
      Plugin.call(:show_profile, service, user) } end

  def self.gen_relationship(api)
    count = gen_counter
    relations = []
    retrieve_interval = "retrieve_interval_#{api}".to_sym
    retrieve_count = "retrieve_count_#{api}".to_sym
    api_created = "#{api}_created".to_sym
    api_destroy = "#{api}_destroy".to_sym
    lambda{ |service|
      if (count.call % UserConfig[retrieve_interval]) == 0
        service.__send__(api, UserConfig[retrieve_count]){ |users|
          index = users.rindex(nil)
          if index and index < (users.size - users.nitems)
            users = service.__send__(api, index.page_of(100)) end
          unless relations.empty?
            created = users - relations
            destroy = relations - users
            unless created.empty?
              Plugin.call(api_created, service, created) end
            unless destroy.empty?
              Plugin.call(api_destroy, service, destroy) end end
          relations = users.select(&ret_nth) } end } end

  def self.set_event(api, title)
    userlist = Gtk::UserList.new()
    proc = gen_relationship(api)
    Plugin.call(:mui_tab_regist, userlist, title, MUI::Skin.get("#{api}.png"))
    Plugin.create(:following_control).add_event(:period){ |service|
      Thread.new{
        res = proc.call(service)
         if res
           users = res.reverse
           Delayer.new{ userlist.add(users).show_all } end } }
    Plugin.create(:following_control).add_event("#{api}_created".to_sym){ |service, users|
      userlist.add(users).show_all }
    Plugin.create(:following_control).add_event("#{api}_destroy".to_sym){ |service, users|
      userlist.remove_if_exists_all(users) }
    Plugin.create(:following_control).add_event(:boot){ |service|
      userlist.double_clicked = open_user(service) } end

  set_event(:followings, 'Followings')
  set_event(:followers, 'Followers')

end
