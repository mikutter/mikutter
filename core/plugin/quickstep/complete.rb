# -*- coding: utf-8 -*-

module Plugin::Quickstep
  class Complete < Gtk::TreeView

    def initialize(search_input)
      super(gen_store)
      append_column ::Gtk::TreeViewColumn.new("", ::Gtk::CellRendererPixbuf.new, pixbuf: Plugin::Quickstep::Store::COL_ICON)
      @col_kind = ::Gtk::TreeViewColumn.new("", ::Gtk::CellRendererText.new, text: Plugin::Quickstep::Store::COL_KIND)
      @col_kind.set_sizing(Gtk::TreeViewColumn::FIXED)
      append_column @col_kind
      append_column ::Gtk::TreeViewColumn.new("", ::Gtk::CellRendererText.new, text: Plugin::Quickstep::Store::COL_TITLE)

      set_enable_search(false)
      set_headers_visible(false)
      set_enable_grid_lines(Gtk::TreeView::GridLines::HORIZONTAL)
      set_tooltip_column(Plugin::Quickstep::Store::COL_TITLE)

      register_listeners(search_input)
    end

    private
    def register_listeners(search_input)
      search_input.ssc(:changed, &method(:input_change_event))
      search_input.ssc(:key_press_event){ |widget, event|
        case ::Gtk::keyname([event.keyval ,event.state])
        when 'Up', 'Control + n'
          path = self.selection.selected.path
          path.prev!
          self.selection.select_path(path)
          true
        when 'Down', 'Control + p'
          path = self.selection.selected.path
          path.next!
          self.selection.select_path(path)
          true
        end
      }
      ssc(:row_activated) do |this, path, _column|
        iter = this.model.get_iter(path)
        if iter
          search_input.signal_emit(:activate)
        end
      end
    end

    def input_change_event(widget)
      @col_kind.set_fixed_width(self.window.geometry[2] * 0.25)
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
      store = Store.new(GdkPixbuf::Pixbuf, String, String, Object)
      store.ssc(:row_inserted, &method(:select_first_ifn))
      store
    end
  end

  class Store < Gtk::ListStore
    COL_ICON  = 0
    COL_KIND  = 1
    COL_TITLE = 2
    COL_MODEL = 3

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
      iter[COL_KIND] = model.class.spec.name
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
      iter[COL_KIND] = 'URLを開く'
      iter[COL_TITLE] = uri.to_s
      iter[COL_MODEL] = uri
    end
  end
end
