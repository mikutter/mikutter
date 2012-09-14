# -*- coding: utf-8 -*-

module Plugin::GUI
  class Command
    Event = Struct.new(:event, :widget, :messages)

    class << self
      def menu_pop
        widget = get_active_widget
        labels = []
        contextmenu = []
        timeline = widget.is_a?(Plugin::GUI::Timeline) ? widget : widget.active_class_of(Plugin::GUI::Timeline)
        event = Event.new(:contextmenu, widget, timeline ? timeline.selected_messages : nil)
        notice "command widget: #{widget} #{timeline}"
        Plugin.filtering(:command, Hash.new).first.values.each{ |record|
          if(record[:visible] and widget.class.find_role_ancestor(record[:role]))
            index = where_should_insert_it(record[:slug].to_s, labels, UserConfig[:mumble_contextmenu_order] || [])
            labels.insert(index, record[:slug].to_s)
            face = record[:show_face] || record[:name] || record[:slug].to_s
            name = if defined? face.call then lambda{ |x| face.call(event) } else face end
            contextmenu.insert(index, [name,
                                       lambda{ |x| record[:condition] === event },
                                       lambda{ |x| record[:exec].call(event) }]) end }
        Plugin.call(:gui_contextmenu, event, contextmenu)
      end

      # フォーカスされているウィジェットを返す。
      # ==== Return
      # 現在アクティブなウィジェット
      def get_active_widget
        chain = Plugin::GUI::Window.active.active_chain
        chain.last if chain
      end
    end

  end
end
