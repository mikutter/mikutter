# -*- coding:utf-8 -*-

Module.new do

  plugin = Plugin::create(:search)

  main = Gtk::TimeLine.new()
  main.force_retrieve_in_reply_to = false
  service = nil

  querybox = Gtk::Entry.new()
  querycont = Gtk::VBox.new(false, 0)
  searchbtn = Gtk::Button.new('検索')
  savebtn = Gtk::Button.new('保存')

  querybox.signal_connect('activate'){ |elm|
    searchbtn.clicked }

  searchbtn.signal_connect('clicked'){ |elm|
    elm.sensitive = querybox.sensitive = false
    main.clear
    service.search(q: querybox.text, rpp: 100).next{ |res|
      main.add(res) if res.is_a? Array
      elm.sensitive = querybox.sensitive = true
    }.trap{ |e|
      main.add(Message.new(message: "検索中にエラーが発生しました (#{e.to_s})", system: true))
      elm.sensitive = querybox.sensitive = true } }

  savebtn.signal_connect('clicked'){ |elm|
    Gtk::Lock.synchronize{
      query = querybox.text
      service.search_create(query: query).next{ |saved_search|
        Plugin.call(:saved_search_regist, saved_search[:id], query)
      }.terminate("検索キーワード「#{query}」を保存できませんでした。あとで試してみてください") } }

  querycont.closeup(Gtk::HBox.new(false, 0).pack_start(querybox).closeup(searchbtn))
  querycont.closeup(Gtk::HBox.new(false, 0).closeup(savebtn))

  plugin.add_event(:boot){ |s|
    service = s
    container = Gtk::VBox.new(false, 0).pack_start(querycont, false).pack_start(main, true)
    Plugin.call(:mui_tab_regist, container, 'Search', MUI::Skin.get("search.png"))
    Message::Entity.addlinkrule(:hashtags, /(?:#|＃)[a-zA-Z0-9_]+/){ |segment|
      querybox.text = '#' + segment[:url].match(/^(?:#|＃)?(.+)$/)[1]
      searchbtn.clicked
      Addon.focus('Search') } }

end

Module.new do

  @tab = Class.new(Addon.gen_tabclass){
    def on_create(*args)
      super
      timeline.force_retrieve_in_reply_to = false
      del = Gtk::Button.new.add(Gtk::WebIcon.new(MUI::Skin.get('close.png'), 16, 16))
      del.signal_connect('clicked'){ |e|
        @service.search_destroy(id: @options[:id]){ |event, dummy|
          remove if event == :success } }
      @header.closeup(del)
    end

    def suffix
      '(Saved Search)' end

    def search(use_cache=false)
      @service.search(q: @options[:query], rpp: 100, cache: use_cache).next{ |res|
        update(res) if res.is_a? Array
      }.terminate
      self end }

  def self.boot
    plugin = Plugin::create(:saved_search)
    plugin.add_event(:boot){ |service|
      @service = service
      @count = 0
      update(UserConfig[:use_cache_first_query]) }

    plugin.add_event(:period){ |service|
      @count += 1
      if(@count >= UserConfig[:retrieve_interval_search])
        update
        @count = 0 end }

    plugin.add_event(:saved_search_regist){ |id, query|
      add_tab(id, query, query) } end

  def self.update(use_cache=false)
    @service.saved_searches(cache: use_cache).next{ |res|
      if res
        remove_unmarked{
          res.each{ |record|
            add_tab(record[:id], URI.decode(record[:query]), URI.decode(record[:name])) } } end }.terminate
  end

  def self.remove_unmarked
    @tab.tabs.each{ |tab|
      tab.mark = false }
    yield
    @tab.tabs.each{ |tab|
      tab.remove if not tab.mark } end

  def self.add_tab(id, query, name)
    tab = @tab.tabs.find{ |tab| tab.name == name }
    if tab
      tab.search.mark = true
      tab.search(:keep)
    else
      @tab.new(name, @service,
               :id => id,
               :query => query,
               :icon => MUI::Skin.get("savedsearch.png")).search(true) end end
  boot
end
