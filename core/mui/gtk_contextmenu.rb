# -*- coding: utf-8 -*-

module Gtk
  class ContextMenu
    extend Gem::Deprecate
    def initialize(*context)
      reset(context) end

    def reset(context)
      @contextmenu = context
    end

    def register(label, condition=ret_nth(), &callback)
      @contextmenu = @contextmenu.push([label, condition, callback]) end
    alias :registmenu :register
    deprecate :registmenu, "register", 2018, 04

    def line
      if block_given?
        register(nil, lambda{ |*a| yield(*a) }){ |a,b| }
      else
        register(nil){ |a,b| } end end
    alias :registline :line
    deprecate :registline, "line", 2018, 04


    # メニューが閉じられた時、自身を自動的に破棄する Gtk::Menu を作成して返す
    def temporary_menu
      menu = Gtk::Menu.new
      menu.ssc(:selection_done) do
        menu.destroy
        false end
      menu.ssc(:cancel) do
        menu.destroy
        false end
      menu end

    def build!(widget, optional, menu = temporary_menu)
     @contextmenu.each{ |param|
        label, cond, proc, icon = param
        if cond.call(*[optional, widget][0, (cond.arity == -1 ? 1 : cond.arity)])
          if label
            label_text = defined?(label.call) ? label.call(*[optional, widget][0, (label.arity == -1 ? 1 : label.arity)]) : label
            if icon.is_a? Proc
              icon = icon.call(*[optional, widget][0, (icon.arity == -1 ? 1 : icon.arity)]) end
            if icon
              item = Gtk::ImageMenuItem.new(label_text)
              item.set_image(Gtk::WebIcon.new(icon, 16, 16))
            else
              item = Gtk::MenuItem.new(label_text)
            end
            if proc
              item.ssc('activate') { |w|
                proc.call(*[optional, widget][0...proc.arity])
                false } end
            menu.append(item)
          else
            menu.append(Gtk::MenuItem.new) end end }
      menu
    end

    def popup(widget, optional)
      menu = build!(widget, optional)

      if not menu.children.empty?
        menu.show_all.popup(nil, nil, 0, 0) end end
  end
end
