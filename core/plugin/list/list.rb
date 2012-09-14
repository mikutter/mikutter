# -*- coding: utf-8 -*-

require 'gtk2'

Plugin.create :list do
  crawl_count = 0
  this = self

  settings "リスト" do
    pack_start(this.setting_container, true)
  end

  on_period do |service|
    crawl_count += 1
    if crawl_count >= UserConfig[:retrieve_interval_list_timeline]
      crawl_count = 0
      fetch_list_of_service(Service.primary)
    end
  end

  on_before_exit_api_section do
    timelines.values.each{ |list|
      list_modify_member(list) } end

  on_appear do |messages|
    messages.each{ |message|
      timelines.each{ |slug, list|
        timeline(slug) << message if list.member.include? message.user } } end

  filter_filter_stream_follow do |users|
    [timelines.values.inject(users){ |r, list| r.merge(list.member) }] end

  # 設定のGtkウィジェット
  def setting_container
    container = Gtk::ListList.new
    container.updated{ |iter|
      notice [iter[0], iter[2]]
      list_set_visibility!(iter[2], iter[0]) }
    container.signal_connect('button_release_event'){ |widget, event|
      if (event.button == 3)
        menu_pop(container)
        true end }
    notice "available_list: #{available_lists.map{|x|x[:full_name]}}"
    available_lists.each{ |list|
      iter = container.model.append
      iter[0] = list_visible?(list)
      iter[1] = list[:full_name]
      iter[2] = list }
    container.show_all end

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
                                  public: list[:public],
                                  cache: cache).next{ |users|
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

  # 自分が作成したリストを返す
  # ==== Return
  # 自分が作成したリストの配列(TypedArray)
  def available_lists
    @available_lists ||= UserLists.new.freeze end

  # 自分が作成したリストを新しく設定する
  # ==== Args
  # [newlist] 新しいリスト(Enumerable)
  # ==== Return
  # _newlist_
  def set_available_lists(newlist)
    @available_lists = UserLists.new(newlist) end

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
      #set_icon
      timeline slug end
    list_modify_member(list, true)
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

  fetch_list_of_service(Service.primary, true)

  class IDs < TypedArray(Integer); end
end
