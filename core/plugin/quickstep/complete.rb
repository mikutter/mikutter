# -*- coding: utf-8 -*-

module Plugin::Quickstep
  class Complete < Gtk::TreeView

    def initialize(search_input)
      super(gen_store)
      append_column ::Gtk::TreeViewColumn.new("", ::Gtk::CellRendererPixbuf.new, pixbuf: Plugin::Quickstep::Store::COL_ICON)
      append_column ::Gtk::TreeViewColumn.new("", ::Gtk::CellRendererText.new, text: Plugin::Quickstep::Store::COL_TITLE)

      register_listeners(search_input)
    end

    private
    def register_listeners(search_input)
      search_input.ssc(:changed, &method(:input_change_event))
    end

    def input_change_event(widget)
      tree_model = self.model = gen_store
      Enumerator.new{ |y|
        Plugin.filtering(:quickstep_query, widget.text.freeze, y)
      }.deach{ |detected|
        tree_model.add_model(detected)
      }.trap{ |err|
        error err
      }
      false
    end

    def select_first_ifn(model, path, iter)
      Delayer.new do
        break if self.destroyed?
        self.selection.select_path(path) unless self.selection.selected
      end
      false
    end

    def gen_store
      store = Store.new(GdkPixbuf::Pixbuf, String, Object)
      store.ssc(:row_inserted, &method(:select_first_ifn))
      store
    end
  end

  class Store < Gtk::ListStore
    COL_ICON  = 0
    COL_TITLE = 1
    COL_MODEL = 2

    def add_model(model)
      case model
      when Diva::Model
        force_add_model(model)
      when Diva::URI, URI::Generic, Addressable::URI, String
        add_uri_or_models(model)
      end
    end

    private

    def force_add_model(model)
      iter = append
      iter[COL_ICON] = nil # model.icon if model.respond_to?(icon)
      iter[COL_TITLE] = model.title
      iter[COL_MODEL] = model
    end

    def add_uri_or_models(uri)
      model_slugs = Plugin.filtering(:model_of_uri, uri.freeze, Set.new).last
      if model_slugs.empty?
        force_add_uri(uri)
      else
        model_slugs.each do |model_slug|
          Deferred.new{
            Diva::Model(model_slug).find_by_uri(uri)
          }.next{|model|
            force_add_model(model) if model
          }.trap do |err|
            error err
          end
        end
      end
    end

    def force_add_uri(uri)
      iter = append
      iter[COL_ICON] = nil
      iter[COL_TITLE] = 'URLを開く: %{uri}' % {uri: uri.to_s}
      iter[COL_MODEL] = uri
    end
  end
end
