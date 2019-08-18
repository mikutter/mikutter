# frozen_string_literal: true

class Gtk::FormDSL::ListView < Gtk::TreeView
  def initialize(parent_dslobj, columns, config)
    @parent_dslobj = parent_dslobj
    @columns = columns
    @config = config
    super()
    store = Gtk::ListStore.new(Object, *([String] * columns.size))

    columns.each_with_index do |(label, _), index|
      col = Gtk::TreeViewColumn.new(label, Gtk::CellRendererText.new, text: index+1)
      #col.resizable = scheme[:resizable]
      append_column(col)
    end

    @parent_dslobj[@config].each do |model|
      iter = store.append
      iter[0] = model
      @columns.each_with_index do |(_, converter), index|
        iter[index + 1] = converter.(model).to_s
      end
    end

    set_model(store)
  end
end
