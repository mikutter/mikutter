# -*- coding: utf-8 -*-

module Plugin::Gtk
  module ToolbarGenerator

    # ツールバーに表示するボタンを _container_ にpackする。
    # 返された時点では空で、後からボタンが入る(showメソッドは自動的に呼ばれる)。
    # ==== Args
    # [container] packするコンテナ
    # ==== Return
    # container
    def self.generate(container, event, role)
      Thread.new{
        Plugin.filtering(:command, {}).first.values.select{ |command|
          command[:visible] and command[:icon] and
            command[:role] == role and command[:condition] === event }
      }.next{ |commands|
        commands.each{ |command|
          face = command[:show_face] || command[:name] || command[:slug].to_s
          name = if defined? face.call then lambda{ |x| face.call(event) } else face end
          toolitem = ::Gtk::Button.new
          toolitem.add(::Gtk::WebIcon.new(command[:icon], 16, 16))
          toolitem.tooltip(name)
          toolitem.relief = ::Gtk::RELIEF_NONE
          toolitem.ssc(:clicked){
            current_world, = Plugin.filtering(:world_current, nil)
            event.world = current_world
            command[:exec].call(event)
            true
          }
          container.closeup(toolitem) }
        #container.ssc(:realize, &:queue_resize)
        container.show_all if not commands.empty?
      }.trap{ |e|
        error "error on command toolbar:"
        error e
      }.terminate
      container end
  end
end
