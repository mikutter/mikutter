module Plugin::Worldon
  class InstanceSettingList < ::Gtk::TreeView
    COL_DOMAIN = 0

    def initialize()
      super()

      Instance.domains.each(&method(:add_record))
    end

    def column_schemer
      [{ kind: :text, type: String, label: 'ドメイン名'}].freeze
    end
    memoize :column_schemer

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
