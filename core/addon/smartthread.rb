
miquire :mui, 'skin'
miquire :addon, 'addon'

require 'set'

Module.new do
  tabclass = Class.new(Addon.gen_tabclass){

    def on_create
      super
      raise if not @options[:message]
      @still_added = Set.new
      close = Gtk::Button.new.add(Gtk::WebIcon.new(MUI::Skin.get('close.png'), 16, 16))
      close.signal_connect('clicked'){ self.remove }
      header.closeup(close).show_all
      set_ancestor(@options[:message])
      focus end

    def set_children(message)
      if message.children.is_a? Array
        Delayer.new{ timeline.add(message.children) }
        message.children.each{ |m|
          if not @still_added.include? m[:id]
            @still_added << m[:id]
            set_children(m) end } end
      self end

    def set_ancestor(message)
      Thread.new{
        message.each_ancestors(true){ |m|
          set_children(m)
          Delayer.new{ timeline.add([m]) } } }
      self end }

  cnt = 0
  counter = lambda{ atomic{ cnt += 1 } }

  plugin = Plugin::create(:smartthread)

  plugin.add_event(:boot){ |service|
    Delayer.new{
      Gtk::Mumble.contextmenu.registmenu('スレッドを表示', lambda{ |m, w|
                                           m.message.repliable? }){ |m, w|
        tabclass.new("Thread #{counter.call}", service,
                  :message => m.message,
                  :icon => MUI::Skin.get("list.png")) } } }

  plugin.add_event(:appear){ |messages|
    tabclass.tabs.each{ |tab|
      rel = messages.select{ |message| message.receive_message and
        tab.timeline.all_id.include?(message.receive_message(true)[:id].to_i) }
      tab.timeline.add(rel) if not rel.empty? } }
end

# Plugin::Ring.push Addon::SmartThread.new,[:boot, :update]
