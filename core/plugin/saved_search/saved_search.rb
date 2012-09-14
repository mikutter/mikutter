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
    add_tab(id, query, query)
  end

  # id => SavedSearch
  def timelines
    @timelines ||= {} end

  # タブを保存する
  # ==== Args
  # [saved_search] saved search
  def add_tab(saved_search)
    notice "add: #{saved_search.query}"
    tab(saved_search.slug, saved_search.name) do
      set_icon MUI::Skin.get("savedsearch.png")
      timeline saved_search.slug end
    rewind_timeline(saved_search)
    timelines[saved_search.id] = saved_search end

  # idに対応するタブを削除
  # ==== Args
  # [id] saved search の ID
  def delete_tab(id)
    saved_search = timelines[id]
    tab(saved_search.slug).destroy if saved_search.slug end

  # タイムラインを更新する
  # ==== Args
  # [saved_search] saved search
  def rewind_timeline(saved_search)
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
        (old_ids - new_ids).each{ |id| delete_tab(id) } end }.terminate
  end

  refresh(true)

end
