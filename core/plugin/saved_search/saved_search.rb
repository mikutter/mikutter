# -*- coding: utf-8 -*-

Plugin.create :saved_search do
  SavedSearch = Struct.new(:id, :query, :name, :slug)

  counter = gen_counter

  on_period do |service|
    if counter.call >= UserConfig[:retrieve_interval_search]
      counter = gen_counter
      timelines.values.each{ |saved_search|
        rewind_timeline(saved_search) } end end

  on_saved_search_regist do |id, query|
    add_tab(SavedSearch.new(id, query, query, ("savedsearch_" + id.to_s).to_sym))
  end

  command(:saved_search_destroy,
          name: '保存した検索を削除',
          condition: lambda{ |opt| timelines.values.any?{ |s| s.slug == opt.widget.slug } },
          visible: true,
          role: :tab) do |opt|
    saved_search = timelines.values.find{ |s| s.slug == opt.widget.slug }
    if saved_search
      Service.primary.search_destroy(id: saved_search.id)
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
    type_strict saved_search => SavedSearch
    tab(saved_search.slug, saved_search.name) do
      set_icon Skin.get("savedsearch.png")
      timeline saved_search.slug end
    rewind_timeline(saved_search)
    register_cache(saved_search)
    timelines[saved_search.id] = saved_search end

  # idに対応するタブを削除
  # ==== Args
  # [id] saved search の ID
  def delete_tab(id)
    type_strict id => Integer
    saved_search = timelines[id]
    tab(saved_search.slug).destroy if saved_search.slug end

  # タイムラインを更新する
  # ==== Args
  # [saved_search] saved search
  def rewind_timeline(saved_search)
    type_strict saved_search => SavedSearch
    Service.primary.search(q: saved_search.query, rpp: 100).next{ |res|
      timeline(saved_search.slug) << res if res.is_a? Array
    }.trap{ |e|
      timeline(saved_search.slug) << Message.new(message: "更新中にエラーが発生しました (#{e.to_s})", system: true) } end

  # saved search を取得する
  # ==== Args
  # [cache] キャッシュの利用方法
  # ==== Return
  # deferred
  def refresh(cache=:keep)
    Service.primary.saved_searches(cache: cache).next{ |res|
      if res
        saved_searches = {}
        res.each{ |record|
          saved_searches[record[:id]] = SavedSearch.new(record[:id], URI.decode(record[:query]), URI.decode(record[:name]), "savedsearch_#{record[:id]}".to_sym) }
        new_ids, old_ids = saved_searches.keys, timelines.keys
        (new_ids - old_ids).each{ |id| add_tab(saved_searches[id]) }
        (old_ids - new_ids).each{ |id| delete_tab(id) } end }.terminate end

  # 保存した検索の情報をキャッシュに登録する
  # ==== Args
  # [saved_search] 保存した検索
  def register_cache(saved_search)
    type_strict saved_search => SavedSearch
    cache = at(:cache, {}).melt
    cache[saved_search.id] = {
      id: saved_search.id,
      query: saved_search.query,
      name: saved_search.name,
      slug: saved_search.slug }
    store(:cache, cache) end

  # 保存した検索の情報をキャッシュから削除
  # ==== Args
  # [id] 削除するID
  def delete_cache(id)
    cache = at(:cache, {}).melt
    cache.delete(id)
    store(:cache, cache) end

  at(:cache, {}).values.each{ |s|
    add_tab(SavedSearch.new(s[:id], URI.decode(s[:query]), URI.decode(s[:name]), s[:slug])) }

  Delayer.new{ refresh(true) }

end








