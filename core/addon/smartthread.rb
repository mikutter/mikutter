# -*- coding: utf-8 -*-

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
      if message.children.is_a? Enumerable
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
    plugin.add_event_filter(:command){ |menu|
      menu[:smartthread] = {
        :slug => :smartthread,
        :name => '会話スレッドを表示',
        :icon => MUI::Skin.get("list.png"),
        :condition => lambda{ |m| m.message.repliable? },
        :exec => lambda{ |m| tabclass.new("Thread #{counter.call}", service,
                                          :message => m.message,
                                          :icon => MUI::Skin.get("list.png")) },
        :visible => true,
        :role => :message }
      [menu]
    }
    # plugin.add_event_filter(:contextmenu){ |menu|
    #   menu << ['スレッドを表示',
    #            lambda{ |m| m.message.repliable? },
    #            lambda{ |opt|
    #              tabclass.new("Thread #{counter.call}", service,
    #                           :message => opt.message,
    #                           :icon => MUI::Skin.get("list.png")) } ]
    #   [menu] }
  }

  plugin.add_event(:appear){ |messages|
    if not tabclass.tabs.empty?
      tabclass.tabs.each{ |tab|
        rel = messages.select{ |message|
          message.has_receive_message? and tab.timeline.any?{ |m|
            r = message.receive_message(false)
            r and m[:id] == r[:id] } }
        tab.timeline.add(rel) if not rel.empty? } end }
end
