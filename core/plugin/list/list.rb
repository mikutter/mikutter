# -*- coding: utf-8 -*-

require 'gtk2'

Plugin.create :list do
  defevent :list_created, priority: :routine_passive, prototype: [Service, UserLists]
  defevent :list_destroy, priority: :routine_passive, prototype: [Service, Array]

  crawl_count = 0

  profiletab :list, _("リスト") do
    set_icon Skin.get("list.png")
    container = ProfileTab.new(Plugin.create(:list), user)
    nativewidget container.show_all end

  on_period do |service|
    crawl_count += 1
    if crawl_count >= UserConfig[:retrieve_interval_list_timeline]
      crawl_count = 0
      fetch_list_of_service(Service.primary).next {
        Deferred.when(*using_lists.map(&method(:list_modify_member))) }.terminate
    end
  end

  filter_extract_datasources do |datasources|
    result = available_lists.inject(datasources||{}) do |_datasources, list|
      _datasources.merge datasource_slug(list) => "@#{list.user.idname}/list/#{list[:name]}" end
    [result] end

  def datasource_slug(list)
    type_strict list => UserList
    :"#{list.user.idname}_list_#{list[:id]}" end

  # available_list の同期をとる。外的要因でリストが追加されたのを検出した場合。
  on_list_created do |service, lists|
    created = lists.reject{ |list| available_lists.include?(list) }
    set_available_lists(service, available_lists(service) + created) if not created.empty? end

  # available_list の同期をとる。外的要因でリストが削除されたのを検出した場合。
  on_list_destroy do |service, lists|
    deleted = lists.select{ |list| available_lists.include?(list) }
    set_available_lists(service, available_lists(service) - deleted) if not deleted.empty? end

  # フォローしているリストを返す
  filter_following_lists do |lists|
    [lists | available_lists] end

  # リストのタイムラインをリアルタイム更新する
  on_appear do |messages|
    messages.each{ |message|
      using_lists.each{ |list|
        if list.related?(message)
          Plugin.call(:extract_receive_message, datasource_slug(list), [message]) end } } end

  on_service_registered do |service|
    if service
      fetch_list_of_service(service, true).next {
        Deferred.when(*using_lists.map{ |list|
                        list_modify_member(list) }) }.terminate end end

  on_service_destroyed do |service|
    service.lists(cache: true, user: service.user_obj).next{ |lists|
      Plugin.call(:list_destroy, service, lists) if lists
    }.terminate
  end

  # FILTER stream で、タイムラインを表示しているユーザをフォロー
  filter_filter_stream_follow do |users|
    [using_lists.inject(users){ |r, list| r.merge(list.member) }] end

  # _service_ が作成した全てのリストを取得する
  # ==== Args
  # [service] リストのオーナーのServiceオブジェクト
  # [cache] キャッシュの利用方法
  # ==== Return
  # deferred
  def fetch_list_of_service(service, cache=:keep)
    type_strict service => Service
    service.lists(cache: cache, user: service.user_obj).next{ |lists|
      if lists
        set_available_lists(service, lists) end } end

  # リストのメンバーを取得する
  # ==== Args
  # [list] リスト
  # [cache] キャッシュの利用方法
  # ==== Return
  # deferred
  def list_modify_member(list, cache=:keep)
    Service.primary.list_members( list_id: list[:id],
                                  mode: list[:mode],
                                  cache: false).next{ |users|
      list.add_member(users) if users
      Service.primary.list_statuses(:id => list[:id],
                                    :cache => cache).next{ |res|
        if res.is_a?(Array) and using?(list)
            Plugin.call(:extract_receive_message, datasource_slug(list), res) end
      }.terminate
    }.trap { |error|
      if defined?(error.httpresponse.code) && 404 == error.httpresponse.code.to_i
        Plugin.call(:list_destroy, Service.primary, [list])
        Plugin.activity :error, "リストが削除されています (#{list[:full_name]})"
      else
        Deferred.fail(error)
      end }.terminate(_("リスト %{list_name} (#%{list_id}) のメンバーの取得に失敗しました") % {
                list_name: list[:full_name],
                list_id: list[:id] }) end

  # 現在データソースで使用されているリストを返す
  # ==== Return
  # Enumerable データソースで使われているリスト
  def using_lists
    list_ids = Plugin.filtering(:extract_tabs_get, []).first.inject(Set.new){ |r,tab|
      r.merge tab[:sources]
    }.map{ |source|
      $1.to_i if source.to_s =~ /[a-zA-Z0-9_]+_list_(\d+)/
    }.compact
    available_lists.select do |list|
      list_ids.include? list[:id] end end

  # list が抽出タブで使われていて、更新を要求されているなら真を返す
  # ==== Args
  # [list] UserList 調べるリスト
  # ==== Return
  # 使われていたら真
  def using?(list)
    using_lists.include? list end

  # 自分がフォローしているリストを返す。
  # _service_ を指定すると、そのアカウントでフォローしているリストに結果を限定する。
  # 結果は重複する可能性がある
  # ==== Args
  # [service] Service|nil リストのフォロイーで絞り込む場合、そのService
  # ==== Return
  # Enumerable 自分がフォローしているリスト(UserList)を列挙する
  def available_lists(service = nil)
    @available_lists ||= Hash.new
    if service
      @available_lists[service.user_obj] ||= UserLists.new.freeze
    else
      @all_available_lists ||= UserLists.new(@available_lists.flat_map{|k,v| v}.uniq.compact).freeze end end

  # _service_ がフォローしているリストを新しく設定する
  # ==== Args
  # [service] Service リストのフォロイー TODO: これ実装する
  # [newlist] Enumerable 新しいリスト
  # ==== Return
  # self
  def set_available_lists(service, newlist)
    type_strict service => Service, newlist => Enumerable
    created = newlist - available_lists(service)
    deleted = available_lists(service) - newlist
    Plugin.call(:list_created, service, UserLists.new(created)) if not created.empty?
    Plugin.call(:list_destroy, service, UserLists.new(deleted)) if not deleted.empty?
    @available_lists[service.user_obj] = UserLists.new(newlist).freeze
    @all_available_lists = nil
    Plugin.call(:list_data, service, available_lists(service)) if not(created.empty? and deleted.empty?)
    self end

  ->(service) {
    if service
      Delayer.new{
        fetch_list_of_service(service, true).next {
          Deferred.when(*using_lists.map(&method(:list_modify_member)))
        }.terminate } end }.(Service.primary)

  class IDs < TypedArray(Integer); end

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
