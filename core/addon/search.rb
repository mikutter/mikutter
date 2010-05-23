
miquire :mui, 'skin'
miquire :addon, 'addon'

class Addon::Search < Addon::Addon

  def onboot(service)
    Delayer.new{
      container = Gtk::VBox.new(false, 0)
      qc = gen_querycont()
      @main = Gtk::TimeLine.new()
      container.pack_start(qc, false).pack_start(@main, true)
      self.regist_tab(service, container, 'Search', MUI::Skin.get("search.png"))
      Gtk::TimeLine.addlinkrule(/#([a-zA-Z0-9_]+)/){ |text, clicked, mumble|
        @querybox.text = text
        @searchbtn.clicked
        focus
      }
    }
    @service = service
  end

  def gen_querycont()
    shell = Gtk::VBox.new(false, 0)
    @querybox = Gtk::Entry.new()
    shell.closeup(Gtk::HBox.new(false, 0).pack_start(@querybox).closeup(search_trigger))
    shell.closeup(Gtk::HBox.new(false, 0).closeup(save_trigger))
  end

  def save_trigger
    btn = Gtk::Button.new('保存')
    btn.signal_connect('clicked'){ |elm|
      Gtk::Lock.synchronize{
        query = @querybox.text
        @service.search_create(query){ |stat, message|
          if(stat = :success)
            Plugin::Ring::fire(:plugincall, [:savedsearch, nil, :saved_search_regist, query]) end
        } } }
    @savebtn = btn
  end

  def search_trigger
    btn = Gtk::Button.new('検索')
    btn.signal_connect('clicked'){ |elm|
      Gtk::Lock.synchronize{
        elm.sensitive = @querybox.sensitive = false
        @main.clear
        @service.search(@querybox.text, :rpp => 100){ |res|
          Gtk::Lock.synchronize{
            @main.add(res) if res.is_a? Array
            elm.sensitive = @querybox.sensitive = true } } } }
    @searchbtn = btn
  end

end

class Addon::SavedSearch < Addon::Addon

  class Tab < Addon::Addon
    attr_reader :query, :name, :tab
    attr_accessor :mark

    def initialize(query, name, service)
      @query, @name, @service, @tab, @mark = query, name, service, Gtk::TimeLine.new, true
      self.regist_tab(@service, @tab, actual_name, MUI::Skin.get("savedsearch.png"))
      search end

    def actual_name
      @name + '(Saved Search)' end

    def update(msgs)
      @tab.add(msgs.select{|msg| not @tab.any?{ |m| m[:id] == msg[:id] } }) end

    def remove
      self.remove_tab(actual_name) end

    def search
      @service.search(@query, :rpp => 100){ |res|
        Gtk::Lock.synchronize{
          update(res) if res.is_a? Array } }
      self end end

  def onperiod(service)
    @count += 1
    if(@count >= UserConfig[:retrieve_interval_search])
      update
      @count = 0 end end

  def onboot(service)
    @service = service
    @tabs = Hash.new
    @count = 0
    update end

  def onplugincall(watch, command, *args)
    case command
    when :saved_search_regist:
        add_tab(args[0], args[0])
    end
  end

  def update
    Thread.new{
      Delayer.new(Delayer::NORMAL, searches){ |found|
        remove_unmarked{
          found.each{ |record|
            add_tab(record['query'], record['name']) } } } } end

  def remove(name)
    @tabs[name].remove
    @tabs.delete(name) end

  def remove_unmarked
    Gtk::Lock.synchronize{
      @tabs.each_pair{ |name, tab|
        tab.mark = false }
      yield
      @tabs.dup.each_pair{ |name, tab|
        remove(name) if not tab.mark } } end

  def searches
    found = @service.scan(:saved_searches)
    return found if(found)
    searches end

  def add_tab(query, name)
    if @tabs.has_key?(name)
      @tabs[name].search.mark = true
    else
      Gtk::Lock.synchronize{
        @tabs[name] = Tab.new(query, name, @service) } end end end

Plugin::Ring.push Addon::Search.new,[:boot]
Plugin::Ring.push Addon::SavedSearch.new,[:period, :boot, :plugincall]
