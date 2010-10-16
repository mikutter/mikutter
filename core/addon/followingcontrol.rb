miquire :addon, 'addon'
miquire :mui, 'skin'
miquire :mui, 'userlist'

require 'enumerator'

Module.new do

  def self.open_user(service)
    lambda{ |user|
      Plugin.call(:show_profile, service, user) } end

  def self.boot_event(api, service, created, destroy)
    unless created.empty?
      Plugin.call("#{api}_created".to_sym, service, created) end
    unless destroy.empty?
      Plugin.call("#{api}_destroy".to_sym, service, destroy) end end

  def self.gen_relationship(api)
    count = gen_counter
    relations = []
    retrieve_interval = "retrieve_interval_#{api}".to_sym
    retrieve_count = "retrieve_count_#{api}".to_sym
    lambda{ |service|
      if (count.call % UserConfig[retrieve_interval]) == 0
        service.__send__(api, UserConfig[retrieve_count]){ |users|
          users = users.select(&ret_nth).freeze
          boot_event(api, service, users - relations, relations - users) unless relations.empty?
          relations = users } end } end

  def self.set_event(api, title)
    userlist = Gtk::UserList.new()
    proc = gen_relationship(api)
    Plugin.call(:mui_tab_regist, userlist, title, MUI::Skin.get("#{api}.png"))
    Plugin.create(:following_control).add_event(:period){ |service|
      Thread.new{
        res = proc.call(service)
         unless res.nil?
           Delayer.new{ userlist.add(res.reverse).show_all } end } }
    Plugin.create(:following_control).add_event("#{api}_created".to_sym){ |service, users|
      userlist.add(users).show_all }
    Plugin.create(:following_control).add_event("#{api}_destroy".to_sym){ |service, users|
      userlist.remove_if_exists_all(users) }
    Plugin.create(:following_control).add_event(:boot){ |service|
      userlist.double_clicked = open_user(service) } end

  set_event(:followings, 'Followings')
  set_event(:followers, 'Followers')

end
