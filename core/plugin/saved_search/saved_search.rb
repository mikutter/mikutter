# -*- coding: utf-8 -*-

module Plugin::SavedSearch
  SavedSearch = Struct.new(:id,      # Saved Search ID (Twitter APIが採番するもの)
                           :query,   # 検索クエリ文字列
                           :name,    # 検索の名前
                           :slug,    # Timeline, Tabのスラッグ
                           :service) # この検索を作成したService
end

Plugin.create :saved_search do

  counter = gen_counter

  on_period do |service|
    if counter.call >= UserConfig[:retrieve_interval_search]
      counter = gen_counter
      refresh end end

  on_saved_search_register do |id, query, service|
    add_tab(Plugin::SavedSearch::SavedSearch.new(id,
                                                 query,
                                                 query,
                                                 :"savedsearch_#{id.to_s}",
                                                 service)) end

  command(:saved_search_destroy,
          name: _('保存した検索を削除'),
          condition: lambda{ |opt| timelines.values.any?{ |s| s.slug == opt.widget.slug } },
          visible: true,
          role: :tab) do |opt|
    saved_search = timelines.values.find{ |s| s.slug == opt.widget.slug }
    if saved_search
      saved_search.service.search_destroy(id: saved_search.id)
      opt.widget.destroy end end

  on_gui_destroy do |i_tab|
    if i_tab.is_a? Plugin::GUI::Tab
      saved_search = timelines.values.find{ |s| s.slug == i_tab.slug }
      if saved_search
        delete_cache(saved_search.id) end end end

  # id => SavedSearch
  def timelines
    @timelines ||= {} end

  # タブを保存する
  # ==== Args
  # [saved_search] saved search
  def add_tab(saved_search)
    type_strict saved_search => Plugin::SavedSearch::SavedSearch
    tab(saved_search.slug, saved_search.name) do
      set_icon Skin['savedsearch.png']
      timeline saved_search.slug end
    register_cache(saved_search)
    timelines[saved_search.id] = saved_search end

  # idに対応するタブを削除
  # ==== Args
  # [id] saved search の ID
  def delete_tab(id)
    type_strict id => Integer
    saved_search = timelines[id]
    timelines.delete(id)
    tab(saved_search.slug).destroy if saved_search.slug end

  # タイムラインを更新する
  # ==== Args
  # [saved_search] saved search
  def rewind_timeline(saved_search)
    type_strict saved_search => Plugin::SavedSearch::SavedSearch
    saved_search.service.search(q: saved_search.query, count: 100).next{ |res|
      timeline(saved_search.slug) << res if res.is_a? Array
    }.trap{ |e|
      timeline(saved_search.slug) << Mikutter::System::Message.new(description: _("更新中にエラーが発生しました (%{error})") % {error: e.to_s}) } end

  # 全 Service について saved search を取得する
  # ==== Args
  # [cache] キャッシュの利用方法
  # ==== Return
  # deferred
  def refresh(cache=:keep)
    Deferred.when(*Service.map { |service| refresh_for_service(service, cache) }) end

  # あるServiceに対してのみ saved search 一覧を取得する
  # ==== Args
  # [service] Service 対象となるService
  # [cache] キャッシュの利用方法
  # ==== Return
  # deferred
  def refresh_for_service(service, cache=:keep)
    service.saved_searches(cache: cache).next{ |res|
      if res
        saved_searches = {}
        res.each{ |record|
          saved_searches[record[:id]] = Plugin::SavedSearch::SavedSearch.new(record[:id],
                                                                             URI.decode(record[:query]),
                                                                             URI.decode(record[:name]),
                                                                             :"savedsearch_#{record[:id]}",
                                                                             service) }
        new_ids = saved_searches.keys
        old_ids = timelines.values.select{|s| s.service == service }.map(&:id)
        (new_ids - old_ids).each{ |id| add_tab(saved_searches[id]) }
        (old_ids - new_ids).each{ |id| delete_tab(id) }
        new_ids.each{ |id| rewind_timeline(saved_searches[id]) } end }.terminate end

  # 保存した検索の情報をキャッシュに登録する
  # ==== Args
  # [saved_search] 保存した検索
  def register_cache(saved_search)
    type_strict saved_search => Plugin::SavedSearch::SavedSearch
    cache = at(:last_saved_search_state, {}).melt
    cache[saved_search.id] = {
      id: saved_search.id,
      query: saved_search.query,
      name: saved_search.name,
      slug: saved_search.slug,
      service_id: saved_search.service.user_obj.id
    }
    store(:last_saved_search_state, cache) end

  # 保存した検索の情報をキャッシュから削除
  # ==== Args
  # [id] 削除するID
  def delete_cache(id)
    cache = at(:last_saved_search_state, {}).melt
    cache.delete(id)
    store(:last_saved_search_state, cache) end

  # ユーザIDから対応する Service を返す
  # ==== Args
  # [user_id] ユーザID
  # ==== Return
  # Service か、見つからなければnil
  def service_by_user_id(user_id)
    Enumerator.new{|y|
      Plugin.filtering(:worlds, y)
    }.lazy.select{ |world|
      world.class.slug == :twitter
    }.find{ |twitter|
      twitter.user_obj.id == user_id
    }
  end

  Delayer.new do
    at(:last_saved_search_state, {}).values.each{ |s|
      service = service_by_user_id(s[:service_id])
      if service
        add_tab(Plugin::SavedSearch::SavedSearch.new(s[:id],
                                                     URI.decode(s[:query]),
                                                     URI.decode(s[:name]),
                                                     s[:slug],
                                                     service))
      elsif s[:slug]
        zombie_tab = tab(s[:slug])
        zombie_tab.destroy if zombie_tab end }
  end
  
  Delayer.new{ refresh(true) }

end








