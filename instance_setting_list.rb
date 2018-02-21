module Plugin::Worldon
  class InstanceSettingList < ::Gtk::TreeView
    include Gtk::TreeViewPrettyScroll
    COL_DOMAIN = 0

    def initialize()
      super()
      set_model(::Gtk::ListStore.new(String))
      append_column ::Gtk::TreeViewColumn.new("ドメイン名", ::Gtk::CellRendererText.new, text: COL_DOMAIN)

      Instance.domains.each(&method(:add_record))
    end

    def selected_domain
      selected_iter = selection.selected
      selected_iter[COL_DOMAIN] if selected_iter
    end

    def add_record(domain)
      iter = model.append
      iter[COL_DOMAIN] = domain
      self
    end

    def remove_record(domain)
      remove_iter = model.to_enum(:each).map{|_,_,iter| iter }.find{|iter| domain == iter[COL_DOMAIN] }
      model.remove(remove_iter) if remove_iter
      self
    end
  end
end
