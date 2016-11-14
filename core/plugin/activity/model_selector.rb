# -*- coding: utf-8 -*-
module Plugin::Activity
  class ModelSelector < Gtk::TreeView
    ICON = 0
    MODEL_KIND = 1
    TITLE = 2
    MODEL = 3
    def initialize(*rest)
      super
      initialize_model
      initialize_column
      set_headers_visible(false)
      self.ssc(:row_activated, &self.class.open_block)
    end

    def set(models)
      model.clear
      models.each do |record|
        iter = model.append
        if record[:profile_image_url]
          iter[ICON] = Gdk::WebImageLoader.pixbuf(record[:profile_image_url], 24, 24) do |loaded_icon|
            iter[ICON] = loaded_icon
          end
        end
        iter[MODEL_KIND] = record.class.model_spec[:name]
        iter[TITLE] = (record[:title] || record[:name] || record[:description] || record.to_s).gsub("\n", '')
        iter[MODEL] = record
      end
    end

    private

    def initialize_model
      set_model(Gtk::ListStore.new(GdkPixbuf::Pixbuf, String, String, Retriever::Model))
    end

    def initialize_column
      initialize_column_icon
      initialize_column_type
      initialize_column_title
    end

    def initialize_column_icon
      col = Gtk::TreeViewColumn.new('icon', Gtk::CellRendererPixbuf.new, pixbuf: 0)
      col.resizable = false
      append_column(col)
    end

    def initialize_column_type
      col = Gtk::TreeViewColumn.new('kind', Gtk::CellRendererText.new, text: 1)
      col.resizable = false
      append_column(col)
    end

    def initialize_column_title
      col = Gtk::TreeViewColumn.new('title', Gtk::CellRendererText.new, text: 2)
      col.resizable = false
      append_column(col)
    end

    def self.open_block
      ->(treeview, path, column) {
        iter = treeview.model.get_iter(path)
        Plugin.call(:open, iter[MODEL])
        false
      }
    end

  end
end
