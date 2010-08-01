#
# ユーザグループリスト用リストビュー
#

require 'gtk2'
miquire :mui, 'extension'

class Gtk::ListList < Gtk::ScrolledWindow
  attr_reader :model, :view

  # proc(iter) ... check box clicked callback
  #            ... iter=[bool toggled, String label, Object optional]
  def initialize(&proc)
    super
    @model = Gtk::ListStore.new(TrueClass, String, Object)
    @view = Gtk::TreeView.new(@model)
    add_with_viewport(@view).show_all
    toggled = Gtk::CellRendererToggle.new
    toggled.signal_connect('toggled'){ |toggled, path|
      iter = @model.get_iter(path)
      proc.call(iter) }
    col = Gtk::TreeViewColumn.new('表示', toggled, :active => 0)
    col.resizable = false
    @view.append_column(col)

    col = Gtk::TreeViewColumn.new('ユーザID', Gtk::CellRendererText.new, :text => 1)
    col.resizable = true
    @view.append_column(col)
  end

  def set_auto_get(&proc)
    plugin = Plugin::create(:listlist)
    create = plugin.add_event :list_create, &plugin.fetch_event(:list_data){ |service, lists|
      lists.each{ |list|
        iter = @model.append
        iter[0] = proc.call(list)
        iter[1] = list['full_name']
        iter[2] = list } }
    destroy = plugin.add_event(:list_destroy){ |service, list_ids|
      @view.each{ |model, path, iter|
        @view.remove(iter) if list_ids.include?(iter[2]['id']) } }
    @view.signal_connect('destroy-event'){ |w, event|
      plugin.detach(create).detach(destroy) }
    self end
end
