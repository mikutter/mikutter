# -*- coding: utf-8 -*-
module ::Plugin::ChangeAccount
  class AccountControl < Gtk::TreeView
    include Gtk::TreeViewPrettyScroll
    COL_ICON = 0
    COL_NAME = 1
    COL_WORLD_NAME = 2
    COL_WORLD = 3

    type_register
    signal_new(:delete_world, GLib::Signal::RUN_FIRST, nil, nil, Array)

    def initialize(plugin)
      @plugin = plugin
      super()
      set_model(::Gtk::ListStore.new(GdkPixbuf::Pixbuf, String, String, Object))
      append_column ::Gtk::TreeViewColumn.new("", ::Gtk::CellRendererPixbuf.new, pixbuf: COL_ICON)
      append_column ::Gtk::TreeViewColumn.new("name", ::Gtk::CellRendererText.new, text: COL_NAME)
      append_column ::Gtk::TreeViewColumn.new("provider", ::Gtk::CellRendererText.new, text: COL_WORLD_NAME)
      content_initialize
      register_signal_handlers
      event_listener_initialize
    end

    def selected_worlds
      self.selection.to_enum(:selected_each).map {|model, path, iter|
        iter[COL_WORLD]
      }
    end

    private

    def content_initialize
      Enumerator.new{|y|
        Plugin.filtering(:worlds, y)
      }.each(&method(:add_column))
    end

    def add_column(world)
      iter = model.append
      if world.respond_to?(:icon) && world.icon
        iter[COL_ICON] = world.icon.load_pixbuf(width: 16, height: 16) do |loaded|
          iter[COL_ICON] = loaded unless destroyed?
        end
      end
      iter[COL_NAME] = world.title
      iter[COL_WORLD_NAME] = world.class.slug
      iter[COL_WORLD] = world
    end

    def menu_pop(widget, event)
      contextmenu = Gtk::ContextMenu.new
      contextmenu.register("削除") do
        signal_emit(:delete_world, selected_worlds)
      end
      contextmenu.popup(widget, widget)
    end

    def event_listener_initialize
      tag = @plugin.handler_tag do
        @plugin.on_world_after_created do |world|
          add_column(world)
        end
        @plugin.on_world_destroy do |world|
          _, _, iter = Enumerator.new(model).find{|m,p,i| i[COL_WORLD] == world }
          model.remove(iter) if iter
        end
      end
      register_detach_listener_at_destroy(tag)
    end

    def register_signal_handlers
      ssc(:button_release_event) do |widget, event|
        if (event.button == 3)
          menu_pop(self, event)
          true
        end
      end
    end

    def register_detach_listener_at_destroy(tag)
      ssc(:destroy) do
        @plugin.detach(tag)
        false
      end
    end

    def signal_do_delete_world(worlds)
    end

  end
end
