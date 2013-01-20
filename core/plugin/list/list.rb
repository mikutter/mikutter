# -*- coding: utf-8 -*-

require 'gtk2'

Plugin.create :list do
  crawl_count = 0
  this = self

  settings "リスト" do
    pack_start(this.setting_container, true)
  end

  profiletab :list, "リスト" do
    set_icon Skin.get("list.png")
    bio = ::Gtk::IntelligentTextview.new(user[:detail])
    ago = (Time.now - (user[:created] or 1)).to_i / (60 * 60 * 24)
    container = ProfileTab.new(Plugin.create(:list), user)
    nativewidget container.show_all end

  on_period do |service|
    crawl_count += 1
    if crawl_count >= UserConfig[:retrieve_interval_list_timeline]
      crawl_count = 0
      fetch_list_of_service(Service.primary).next {
        timelines.values.each{ |list|
          list_modify_member(list) } }
    end
  end

  # available_list の同期をとる。外的要因でリストが追加されたのを検出した場合。
  on_list_created do |service, lists|
    created = lists.reject{ |list| available_lists.include?(list) }
    set_available_lists(available_lists + created) if not created.empty? end

  # available_list の同期をとる。外的要因でリストが削除されたのを検出した場合。
  on_list_destroy do |service, lists|
    deleted = lists.select{ |list| available_lists.include?(list) }
    set_available_lists(available_lists - deleted) if not deleted.empty? end

  # フォローしているリストを返す
  filter_following_lists do |lists|
    [lists | available_lists] end

  # リストのタイムラインをリアルタイム更新する
  on_appear do |messages|
    messages.each{ |message|
      timelines.each{ |slug, list|
        if list.related?(message)
          timeline(slug) << message end } } end

  # filter stream で、タイムラインを表示しているユーザをフォロー
  filter_filter_stream_follow do |users|
    [timelines.values.inject(users){ |r, list| r.merge(list.member) }] end

  # 設定のGtkウィジェット
  def setting_container
    tab = Tab.new
    tab.plugin = self
    available_lists.each{ |list|
      iter = tab.model.append
      iter[Tab::VISIBILITY] = list_visible?(list)
      iter[Tab::SLUG] = list[:full_name]
      iter[Tab::LIST] = list
      iter[Tab::NAME] = list[:name]
      iter[Tab::DESCRIPTION] = list[:description]
      iter[Tab::PUBLICITY] = list[:mode] }
    Gtk::HBox.new.add(tab).closeup(tab.buttons(Gtk::VBox)).show_all end

  # _service_ が作成した全てのリストを取得する
  # ==== Args
  # [service] リストのオーナーのServiceオブジェクト
  # [cache] キャッシュの利用方法
  # ==== Return
  # deferred
  def fetch_list_of_service(service, cache=:keep)
    type_strict service => Service
    param = {:cache => cache, :user => service.user_obj}
    service.lists(param).next{ |lists|
      if lists
        set_available_lists(lists)
        tab_reflesh{
          lists.each{ |list|
            tab_mark(list) } } end }.terminate
  end

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
        if res.is_a? Array
          slug = timelines.keys.find{ |slug| timelines[slug] == list }
          timeline(slug) << res if slug end
      }.terminate
    }.terminate("リスト #{list[:full_name]} (##{list[:id]}) のメンバーの取得に失敗しました") end

  # 表示中のタイムライン/タブのスラッグとリストオブジェクトの連想配列
  def timelines
    @timelines ||= {} end

  # 表示設定されているリストのIDを返す
  # ==== Return
  # 表示できるリストのIDの配列(TypedArray)
  def visible_list_ids
    at(:visible_lists, []).freeze end

  # リストを表示可能に設定する。すでに表示可能にセットされている場合は何もしない
  # ==== Args
  # [list] 表示可能にするリスト
  # ==== Return
  # self
  def list_set_visibility(list)
    type_strict list => UserList
    visible_lists = at(:visible_lists, [])
    if not visible_lists.include?(list[:id])
      store(:visible_lists, (visible_lists + [list[:id]]).uniq) end
    self end

  # リストを非表示に設定する。すでに非表示にセットされている場合は何もしない
  # ==== Args
  # [list] 非表示にするリスト
  # ==== Return
  # self
  def list_set_hide(list)
    type_strict list => UserList
    visible_lists = at(:visible_lists, [])
    if visible_lists.include?(list[:id])
      store(:visible_lists, visible_lists - [list[:id]]) end
    visible_list_obj = at(:visible_list_obj, {}).melt
    visible_list_obj.delete(list[:id])
    store(:visible_list_obj, visible_list_obj)
    self end

  # _list_ の表示可否状態を _visibility_ にして、実際に表示/非表示を切り替える
  # ==== Args
  # [list] リスト
  # [visibility] trueなら表示、falseなら非表示
  # ==== Return
  # self
  def list_set_visibility!(list, visibility)
    type_strict list => UserList
    if visibility
      list_set_visibility(list)
      tab_open(list)
    else
      list_set_hide(list)
      tab_close(list) end
    self end

  # そのタブが表示する設定になっているかどうかを返す
  # ==== Args
  # [list] リスト
  # ==== Return
  # タブが表示する設定になっているなら真
  def list_visible?(list)
    type_strict list => UserList
    visible_list_ids.include? list[:id] end

  # 自分がフォローしているリストを返す
  # ==== Return
  # 自分が作成したリストの配列(TypedArray)
  def available_lists
    @available_lists ||= UserLists.new.freeze end

  # 自分がフォローしているリストを新しく設定する
  # ==== Args
  # [newlist] 新しいリスト(Enumerable)
  # ==== Return
  # _newlist_
  def set_available_lists(newlist)
    created = newlist - available_lists
    deleted = available_lists - newlist
    Plugin.call(:list_created, Service.primary, created.freeze) if not created.empty?
    Plugin.call(:list_destroy, Service.primary, deleted.freeze) if not deleted.empty?
    @available_lists = UserLists.new(newlist).freeze
    Plugin.call(:list_data, Service.primary, @available_lists) if not(created.empty? and deleted.empty?)
    @available_lists end

  # このブロック中で _add_tab(list)_ を呼ばれなかったリストは、ブロックを出た時に全て削除される。
  # また、新たにマークを付けられたタブは、タブが作成される。
  # ==== Return
  # ブロックの戻り値
  def tab_reflesh
    @tab_reflesh ||= Mutex.new
    @tab_reflesh.synchronize do
      @mark = Set.new
      result = yield
      available_lists.each{ |list|
        if @mark.include? list
          tab_open(list)
        else
          tab_close(list) end }
      result end end

  # _list_ に対応するタブにマークをつける。
  # ==== Args
  # [list] リスト
  def tab_mark(list)
    type_strict list => UserList
    if list_visible?(list)
      @mark << list end end

  # _list_ のためのタブを開く。タブがすでに有る場合は何もしない。
  # ==== Args
  # [list] リスト
  # ==== Return
  # self
  def tab_open(list)
    type_strict list => UserList
    slug = "list_#{list[:full_name]}".to_sym
    return self if timelines.has_key? slug
    timelines[slug] = list
    tab(slug, list[:full_name]) do
      set_icon Skin.get("list.png")
      timeline slug end
    list_modify_member(list, true)
    visible_list_obj = at(:visible_list_obj, {}).melt
    visible_list_obj[list[:id]] = list.to_hash
    visible_list_obj[list[:id]][:user] = list[:user].to_hash
    store(:visible_list_obj, visible_list_obj)
    self end

  # _list_ のためのタブを閉じる。タブがない場合は何もしない。
  # ==== Args
  # [list] リスト
  # ==== Return
  # self
  def tab_close(list)
    type_strict list => UserList
    slug = timelines.keys.find{ |slug| timelines[slug] == list }
    return self if not timelines.has_key? slug
    if slug
      timelines.delete(slug)
      tab(slug).destroy end
    self end

  Delayer.new{
    fetch_list_of_service(Service.primary, true) }

  at(:visible_list_obj, {}).values.each{ |list|
    begin
      list = UserList.new_ifnecessary(list)
      list[:user] = User.new_ifnecessary(list[:user])
      tab_open(list)
    rescue => e
      error "list redume failed"
      error e end }

  class IDs < TypedArray(Integer); end

  class Tab < ::Gtk::ListList
    attr_accessor :plugin

    VISIBILITY = 0
    SLUG = 1
    LIST = 2
    NAME = 3
    DESCRIPTION = 4
    PUBLICITY = 5

    def initialize
      super
      dialog_title = "リスト" end

    def column_schemer
      [{:kind => :active, :widget => :boolean, :type => TrueClass, :label => '表示'},
       {:kind => :text, :type => String, :label => 'リスト名'},
       {:type => UserList},
       {:type => String, :widget => :input, :label => 'リストの名前'},
       {:type => String, :widget => :input, :label => 'リスト説明'},
       {:type => TrueClass, :widget => :boolean, :label => '公開'},
      ].freeze
    end

    def on_created(iter)
      iter[SLUG] = "@#{Service.primary.user}/#{iter[NAME]}"
      Service.primary.add_list(user: Service.primary.user_obj,
                               mode: iter[PUBLICITY],
                               name: iter[NAME],
                               description: iter[DESCRIPTION]){ |event, list|
        if :success == event and list
          Plugin.call(:list_created, Service.primary, UserLists.new([list]))
          if not(destroyed?)
            iter[LIST] = list
            iter[SLUG] = list[:full_name]
            list_set_visibility!(list, iter[VISIBILITY]) end end } end

    def on_updated(iter)
      list = iter[LIST]
      if list
        plugin.list_set_visibility!(list, iter[VISIBILITY])
        if list[:name] != iter[NAME] || list[:description] != iter[DESCRIPTION] || list[:mode] != iter[PUBLICITY]
          notice "list updated. #{iter[NAME]} #{iter[DESCRIPTION]} #{iter[PUBLICITY]}"
          Service.primary.update_list(id: list[:id],
                               name: iter[NAME],
                               description: iter[DESCRIPTION],
                               mode: iter[PUBLICITY]){ |event, list|
            if not(destroyed?) and event == :success and list
              iter[SLUG] = list[:full_name] end } end end end

    def on_deleted(iter)
      list = iter[LIST]
      if list
        Service.primary.delete_list(list_id: list[:id]){ |event, list|
          if event == :success
            Plugin.call(:list_destroy, Service.primary, UserLists.new([list]))
            model.remove(iter) if not destroyed? end } end end

  end

  class ProfileTab < ::Gtk::ListList
    MEMBER = 0
    SLUG = 1
    LIST = 2
    SERVICE = 3

    def initialize(plugin, dest)
      type_strict plugin => Plugin, dest => User
      @dest_user = dest
      @locked = {}
      super()
      creatable = updatable = deletable = false
      set_auto_getter(plugin, true) do |service, list, iter|
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
      }.terminate("@#{@dest_user[:idname]} が入っているリストが取得できませんでした。雰囲気で適当に表示しておきますね").trap{ |e|
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
            "@#{@dest_user[:idname]} をリスト #{list[:full_name]} に追加できませんでした" } end
      end
    end

    def column_schemer
      [{:kind => :active, :widget => :boolean, :type => TrueClass, :label => 'リスト行き'},
       {:kind => :text, :type => String, :label => 'リスト名'},
       {:type => UserList},
       {:type => Service}
      ].freeze
    end

    # 右クリックメニューを禁止する
    def menu_pop(widget, event)
    end
  end
end
