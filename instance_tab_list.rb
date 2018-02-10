class Plugin::Worldon::InstanceTabList < ::Gtk::TreeView
  ITER_DOMAIN = 0
  ITER_RETRIEVE = 1

  def initialize(plugin)
    type_strict plugin => Plugin
    @plugin = plugin
    super(Gtk::ListStore.new(String, Numeric))
    set_size_request(0, 200)

    append_column(Gtk::TreeViewColumn.new("ドメイン名", Gtk::CellRendererText.new, text: ITER_DOMAIN))

    Instance.domains.each(&method(:add_record))
  end

  def selected_domain
    selected_iter = selection.selected
    selected_iter[ITER_DOMAIN] if selected_iter
  end

  def add_record(domain)
    iter = model.append
    iter[ITER_DOMAIN] = domain
    self
  end

  def remove_record(domain)
    remove_iter = model.to_enum(:each).map{|_,_,iter| iter }.find{|iter| domain == iter[ITER_DOMAIN] }
    model.remove(remove_iter) if remove_iter
    self
  end
end
