# -*- coding: utf-8 -*-

require 'set'

Plugin.create :followingcontrol do

  counter = gen_counter

  on_period do
    target = lazy{ Set.new(Service.instances) - @activating_services }
    count = counter.call
    if 0 == count % UserConfig["retrieve_interval_followings"]
      rewind(:followings, target) end
    if 0 == count % UserConfig["retrieve_interval_followers"]
      rewind(:followers, target) end
  end

  on_followings_created do |service, created|
    user = service.user_obj
    users = relation.followings[user]
    if users
      relation.followings[user] = Users.new((created + users).uniq) end end

  on_followings_destroy do |service, destroyed|
    user = service.user_obj
    users = relation.followings[user]
    if users
      relation.followings[user] = users - destroyed end end

  on_followers_created do |service, created|
    user = service.user_obj
    users = relation.followers[user]
    if users
      relation.followers[user] = Users.new((created + users).uniq) end end

  on_followers_destroy do |service, destroyed|
    user = service.user_obj
    users = relation.followers[user]
    if users
      relation.followers[user] = users - destroyed end end

  filter_message_introducers do |service, source, messages|
    followings = relation.followings[service.user]
    if followings
      [service, source, messages.select{|m| followings.include?(m.user) }]
    else
      [service, source, messages] end end

  profiletab(:followings, _('フォローしている')) do
    set_icon Skin.get("followings.png")
    container = Gtk::EventBox.new
    userlist = gen_userlist
    nativewidget container
    if Service.map(&:user_obj).include?(user)
      userlist.add_user(Users.new((relation.followings[user] || []).reverse))
      events = []
      events << on_followings_created do |service, created|
        if service.user_obj == user
          userlist.add_user(Users.new(created)) end end
      events << on_followings_destroy do |service, destroyed|
        if service.user_obj == user
          userlist.remove_user(Users.new(destroyed)) end end
      events << on_followings_modified do |service, modified|
        if service.user_obj == user
          userlist.listview.model.clear
          userlist.add_user(Users.new(modified.reverse)) end end
      userlist.ssc(:destroy) do
        events.each(&:detach) end
      container.add(userlist).show_all
    else
      container.ssc_atonce :expose_event do
        loading_image = Gtk::WebIcon.new(Skin.get('loading.png'), 128, 128)
        container.add(loading_image.show_all)
        Service.primary.followings(cache: true, user_id: user[:id]).next{ |users|
          container.remove(loading_image)
          loading_image = nil
          container.add(userlist.show_all)
          userlist.add_user(Users.new(users.reverse))
        }.trap{
          loading_image.pixbuf = Gdk::WebImageLoader.notfound_pixbuf(128, 128)
        } end
    end
  end

  profiletab(:followers, _('フォローされている')) do
    set_icon Skin.get("followers.png")
    container = Gtk::EventBox.new
    userlist = gen_userlist
    nativewidget container
    if Service.map(&:user_obj).include?(user)
    userlist.add_user(Users.new((relation.followers[user] || []).reverse))
      events = []
      events << on_followers_created do |service, created|
        if service.user_obj == user
          userlist.add_user(Users.new(created)) end end
      events << on_followers_destroy do |service, destroyed|
        if service.user_obj == user
          userlist.remove_user(Users.new(destroyed)) end end
      events << on_followers_modified do |service, modified|
        if service.user_obj == user
          userlist.listview.model.clear
          userlist.add_user(Users.new(modified.reverse)) end end
      userlist.ssc(:destroy) do
        events.each(&:detach) end
      container.add(userlist).show_all
    else
      container.ssc_atonce :expose_event do
        loading_image = Gtk::WebIcon.new(Skin.get('loading.png'), 128, 128)
        container.add(loading_image.show_all)
        Service.primary.followers(cache: true, user_id: user[:id]).next{ |users|
          container.remove(loading_image)
          loading_image = nil
          container.add(userlist.show_all)
          userlist.add_user(Users.new(users.reverse))
        }.trap{
          loading_image.pixbuf = Gdk::WebImageLoader.notfound_pixbuf(128, 128)
        } end
    end
  end

  def boot
    @activating_services = Set.new
    @relation = Struct.new(:followings, :followers).new(TimeLimitedStorage.new, TimeLimitedStorage.new)

    Service.each(&method(:service_register))
  end

  def gen_userlist
    userlist = Gtk::UserList.new
    userlist.listview.ssc(:row_activated) { |this, path, column|
      iter = this.model.get_iter(path)
      if iter
        Plugin.call(:show_profile, Service.primary, iter[Gtk::InnerUserList::COL_USER]) end }
    #userlist.listview.model.set_sort_column_id(Gtk::InnerUserList::COL_ORDER, Gtk::SORT_ASCENDING)
    userlist end

  def relation
    @relation end

  def rewind(direction, target)
    relation = @relation[direction.to_sym]
    target.each { |service|
      user = service.user_obj
      service.__send__(direction, cache: :keep, user_id: user[:id]).next { |users|
        primitive = relation[user]
        if primitive and not primitive.empty?
          created = users - primitive
          Plugin.call("#{direction}_created".to_sym, service, created) if not created.empty?
          destroyed = primitive - users
          Plugin.call("#{direction}_destroy".to_sym, service, destroyed) if not destroyed.empty?
        else
          relation[user] = Users.new(users)
          Plugin.call("#{direction}_modified".to_sym, service, users)
        end
      }
    }
  end

  # _service_ を監視対象に入れる
  # ==== Args
  # service :: 監視するservice
  def service_register(service)
    @activating_services << service
    user = service.user_obj
    Deferred.when(service.followings(cache: true, user_id: user[:id]),
                  service.followers(cache: true, user_id: user[:id])).next { |followings, followers|
      @relation.followings[user] = Users.new(followings)
      @relation.followers[user] = Users.new(followers)
      Plugin.call(:followings_modified, service, @relation.followings[user])
      Plugin.call(:followers_modified, service, @relation.followers[user])
      @activating_services.delete(service)
    }.trap {
      @activating_services.delete(service)
    }
  end

  boot
end
