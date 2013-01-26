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
      if not menu.children.empty?
        menu.attach_to_widget(widget) {|attach_widgt, mnu| notice "detached" }
        menu.show_all.popup(nil, nil, 0, 0) end end
  end
end
