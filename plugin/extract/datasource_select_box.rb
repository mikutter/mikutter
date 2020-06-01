# frozen_string_literal: true

class Plugin::Extract::DatasourceSelectBox < Gtk::HierarchycalSelectBox
  def initialize(sources, &block)
    super(datasources, sources, &block)
  end

  def datasources
    Plugin.collect(:message_stream).map do |model|
      [model.datasource_slug, model.title.split('/').freeze]
    end
  end

  def menu_pop(widget, _event)
    datasource = selected_datasource_names.first
    if datasource
      contextmenu = Gtk::ContextMenu.new
      contextmenu.register(Plugin[:extract]._('データソース slugをコピー'), &copy_slug(datasource))
      contextmenu.register(Plugin[:extract]._('subscriberをコピー'), &copy_subscriber(datasource))
      contextmenu.popup(widget, widget)
    end
  end

  def copy_slug(datasource)
    ->(_optional=nil, _widget=nil) do
      Gtk::Clipboard.copy(datasource.to_s)
    end
  end

  def copy_subscriber(datasource)
    ->(_optional=nil, _widget=nil) do
      Gtk::Clipboard.copy(<<~'EOM' % {ds: datasource.to_sym.inspect})
      subscribe(:extract_receive_message, %{ds}).each do |message|
        
      end
      EOM
    end
  end

  private

  def selected_datasource_names
    self.selection.to_enum(:selected_each).map {|_, _, iter|
      iter[ITER_ID]
    }
  end
end
