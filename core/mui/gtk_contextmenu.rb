# -*- coding: utf-8 -*-

module Gtk
  class ContextMenu
    def initialize(*context)
      reset(context) end

    def reset(context)
      @contextmenu = context
    end

    def registmenu(label, condition=ret_nth(), &callback)
      @contextmenu = @contextmenu.push([label, condition, callback]) end

    def registline
      if block_given?
        registmenu(nil, lambda{ |*a| yield *a }){ |a,b| }
      else
        registmenu(nil){ |a,b| } end end

    def popup(widget, optional)
      menu = Gtk::Menu.new
      @contextmenu.each{ |param|
        label, cond, proc = param
        if cond.call(*[optional, widget][0, (cond.arity == -1 ? 1 : cond.arity)])
          if label
            item = Gtk::MenuItem.new(if defined? label.call then label.call(*[optional, widget][0, label.arity]) else label end)
            item.signal_connect('activate') { |w| proc.call(*[optional, widget][0...proc.arity]); false } if proc
            menu.append(item)
          else
            menu.append(Gtk::MenuItem.new) end end }
      menu.attach_to_widget(widget) {|attach_widgt, mnu| notice "detached" }
      menu.show_all.popup(nil, nil, 0, 0) end
  end
end
