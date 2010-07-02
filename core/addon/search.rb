miquire :mui, 'skin'
miquire :addon, 'addon'

Module.new do

  plugin = Plugin::create(:friend_timeline)

  main = Gtk::TimeLine.new()
  service = nil

  querybox = Gtk::Entry.new()
  querycont = Gtk::VBox.new(false, 0)
  searchbtn = Gtk::Button.new('検索')
  savebtn = Gtk::Button.new('保存')

  searchbtn.can_default = true
  searchbtn.grab_default
  searchbtn.signal_connect('clicked'){ |elm|
    Gtk::Lock.synchronize{
      elm.sensitive = querybox.sensitive = false
      main.clear
      service.search(querybox.text, :rpp => 100){ |res|
        Gtk::Lock.synchronize{
          main.add(res) if res.is_a? Array
          elm.sensitive = querybox.sensitive = true } } } }

  savebtn.signal_connect('clicked'){ |elm|
    Gtk::Lock.synchronize{
      query = querybox.text
      service.search_create(query){ |stat, message|
        if(stat = :success)
          Plugin::Ring::fire(:plugincall, [:savedsearch, nil, :saved_search_regist, query]) end
      } } }

  querycont.closeup(Gtk::HBox.new(false, 0).pack_start(querybox).closeup(searchbtn))
  querycont.closeup(Gtk::HBox.new(false, 0).closeup(savebtn))

  plugin.add_event(:boot){ |s|
    service = s
    container = Gtk::VBox.new(false, 0).pack_start(querycont, false).pack_start(main, true)
    Plugin.call(:mui_tab_regist, container, 'Search', MUI::Skin.get("search.png"))
    Gtk::TimeLine.addlinkrule(/(#|＃)([a-zA-Z0-9_]+)/){ |text, clicked, mumble|
      querybox.text = text
      searchbtn.clicked
      Addon.focus('Search') } }

end

Module.new do

  @@tab = Class.new(Addon.gen_tabclass('(Saved Search)', nil)){
    def search
      @service.search(@options[:query], :rpp => 100){ |res|
        Gtk::Lock.synchronize{
          update(res) if res.is_a? Array } }
      self end }

  def self.boot
    plugin = Plugin::create(:saved_search)
    plugin.add_event(:boot){ |service|
      @service = service
      @count = 0
      update }

    plugin.add_event(:period){ |service|
      @count += 1
      if(@count >= UserConfig[:retrieve_interval_search])
        update
        @count = 0 end }

    plugin.add_event(:saved_search_regist){ |query|
      add_tab(query, query) } end

  def self.update
    Thread.new{
      Delayer.new(Delayer::NORMAL, searches){ |found|
        remove_unmarked{
          found.each{ |record|
            add_tab(record['query'], record['name']) } } } } end

  def self.remove_unmarked
    Gtk::Lock.synchronize{
      @@tab.tabs.each{ |tab|
        tab.mark = false }
      yield
      @@tab.tabs.each{ |tab|
        tab.remove if not tab.mark } } end

  def self.searches
    found = @service.scan(:saved_searches)
    return found if(found)
    [] end

  def self.add_tab(query, name)
    tab = @@tab.tabs.find{ |tab| tab.name == name }
    if tab
      tab.search.mark = true
    else
      Gtk::Lock.synchronize{
        @@tab.new(name, @service,
                  :query => query,
                  :icon => MUI::Skin.get("savedsearch.png")).search } end end
  boot
end

# Plugin::Ring.push Addon::Search.new,[:boot]
# Plugin::Ring.push Addon::SavedSearch.new,[:period, :boot, :plugincall]
