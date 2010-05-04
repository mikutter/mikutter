
miquire :addon, 'addon'

module Addon
  class Search < Addon

    def onboot(service)
      Gtk::Lock.synchronize{
        container = Gtk::VBox.new(false, 0)
        qc = gen_querycont()
        @main = Gtk::TimeLine.new()
        container.pack_start(qc, false).pack_start(@main, true)
        self.regist_tab(service, container, 'Search', "core#{File::SEPARATOR}skin#{File::SEPARATOR}data#{File::SEPARATOR}search.png")
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
end

Plugin::Ring.push Addon::Search.new,[:boot]
