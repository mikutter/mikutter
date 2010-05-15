
miquire :mui, 'skin'
miquire :addon, 'addon'

module Addon
  class Search < Addon

    def onboot(service)
      Delayer.new{
        container = Gtk::VBox.new(false, 0)
        qc = gen_querycont()
        @main = Gtk::TimeLine.new()
        container.pack_start(qc, false).pack_start(@main, true)
        self.regist_tab(service, container, 'Search', MUI::Skin.get("search.png"))
        Gtk::TimeLine.addlinkrule(/#([a-zA-Z0-9_]+)/){ |text|
          @querybox.text = text
          @searchbtn.clicked
          focus
        }
      }
      @service = service
    end

    def gen_querycont()
      qc = Gtk::HBox.new(false, 0)
      @querybox = Gtk::Entry.new()
      qc.pack_start(@querybox).pack_start(search_trigger, false)
    end

    def search_trigger
      btn = Gtk::Button.new('検索')
      btn.signal_connect('clicked'){ |elm|
        Gtk::Lock.synchronize{
          elm.sensitive = false
          @querybox.sensitive = false
          @main.clear
          @service.search(@querybox.text, :rpp => 100){ |res|
            Gtk::Lock.synchronize{
              if res.is_a? Array
                @main.add(res)
              end
              elm.sensitive = true
              @querybox.sensitive = true } } } }
      @searchbtn = btn
    end

  end

  class SavedSearch < Addon

    class Tab < Addon
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
      update if(@count >= UserConfig[:retrieve_interval_search]) end

    def onboot(service)
      @service = service
      @tabs = Hash.new
      @count = 0
      update end

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
          @tabs[name] = Tab.new(query, name, @service) } end end end end

Plugin::Ring.push Addon::Search.new,[:boot]
Plugin::Ring.push Addon::SavedSearch.new,[:period, :boot]
