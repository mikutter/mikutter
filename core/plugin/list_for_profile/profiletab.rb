# -*- coding: utf-8 -*-

require 'gtk2'

module Plugin::ListForProfile
  class ProfileTab < ::Gtk::ListList
    MEMBER = 0
    SLUG = 1
    LIST = 2
    SERVICE = 3

    def initialize(plugin, dest)
      type_strict plugin => Plugin, dest => User
      @plugin = plugin
      @dest_user = dest
      @locked = {}
      super()
      creatable = updatable = deletable = false
      set_auto_getter(@plugin, true) do |service, list, iter|
        iter[MEMBER] = list.member?(@dest_user)
        iter[SLUG] = list[:slug]
        iter[LIST] = list
        iter[SERVICE] = service end
      toggled = get_column(0).cell_renderers[0]
      toggled.activatable = false
      Service.primary.list_user_followers(user_id: @dest_user[:id], filter_to_owned_lists: 1).next{ |res|
        if res and not destroyed?
          followed_list_ids = res.map{|list| list['id'].to_i}
          model.each{ |m, path, iter|
            if followed_list_ids.include? iter[LIST][:id]
              iter[MEMBER] = true
              iter[LIST].add_member(@dest_user) end }
          toggled.activatable = true
          queue_draw end
      }.terminate(@plugin._("@%{user} が入っているリストが取得できませんでした。雰囲気で適当に表示しておきますね") % {user: @dest_user[:idname]}).trap{ |e|
        if not destroyed?
          toggled.activatable = true
          queue_draw end } end

    def on_updated(iter)
      if iter[LIST].member?(@dest_user) != iter[MEMBER]
        if not @locked[iter[SLUG]]
          @locked[iter[SLUG]] = true
          flag, slug, list, service = iter[MEMBER], iter[SLUG], iter[LIST], iter[SERVICE]
          service.__send__(flag ? :add_list_member : :delete_list_member,
                           :list_id => list['id'],
                           :user_id => @dest_user[:id]).next{ |result|
            @locked[slug] = false
            if flag
              list.add_member(@dest_user)
              Plugin.call(:list_member_added, service, @dest_user, list, service.user_obj)
            else
              list.remove_member(@dest_user)
              Plugin.call(:list_member_removed, service, @dest_user, list, service.user_obj) end
          }.terminate{ |e|
            iter[MEMBER] = !flag if not destroyed?
            @locked[iter[SLUG]] = false
            @plugin._("@%{user} をリスト %{list_name} に追加できませんでした") % {
              user: @dest_user[:idname],
              list_name: list[:full_name] } } end end end

    def column_schemer
      [{:kind => :active, :widget => :boolean, :type => TrueClass, :label => @plugin._('リスト行き')},
       {:kind => :text, :type => String, :label => @plugin._('リスト名')},
       {:type => UserList},
       {:type => Service}
      ].freeze
    end

    # 右クリックメニューを禁止する
    def menu_pop(widget, event)
    end
  end
end
