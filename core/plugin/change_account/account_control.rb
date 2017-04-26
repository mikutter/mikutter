# -*- coding: utf-8 -*-
module ::Plugin::ChangeAccount
  class AccountControl < Gtk::TreeView
    include Gtk::TreeViewPrettyScroll
    COL_ICON = 0
    COL_NAME = 1
    COL_WORLD_NAME = 2
    COL_ACCOUNT = 3

    def initialize(plugin)
      @plugin = plugin
      super(::Gtk::ListStore.new(GdkPixbuf::Pixbuf, String, String, Object))
      append_column ::Gtk::TreeViewColumn.new("", ::Gtk::CellRendererPixbuf.new, pixbuf: COL_ICON)
      append_column ::Gtk::TreeViewColumn.new("name", ::Gtk::CellRendererText.new, text: COL_NAME)
      append_column ::Gtk::TreeViewColumn.new("provider", ::Gtk::CellRendererText.new, text: COL_WORLD_NAME)
      content_initialize
      event_listener_initialize
    end

    private

    def content_initialize
      Enumerator.new{|y|
        Plugin.filtering(:accounts, y)
      }.each(&method(:add_column))
    end

    def add_column(account)
      iter = model.append
      if account.respond_to?(:icon) && account.icon
        iter[COL_ICON] = account.icon.load_pixbuf(width: 16, height: 16) do |loaded|
          iter[COL_ICON] = loaded unless destroyed?
        end
      end
      iter[COL_NAME] = account.name
      iter[COL_WORLD_NAME] = account.class.slug
      iter[COL_ACCOUNT] = account
    end

    def event_listener_initialize
      tag = @plugin.handler_tag do
        @plugin.on_account_add do |account|
          add_column(account)
        end
        @plugin.on_account_destroy do |account|
          _, _, iter = Enumerator.new(model).find{|m,p,i| i[COL_ACCOUNT] == account }
          model.remove(iter) if iter
        end
      end
      register_detach_listener_at_destroy(tag)
    end

    def register_detach_listener_at_destroy(tag)
      ssc(:destroy) do
        @plugin.detach(tag)
        false
      end
    end

  end
end
