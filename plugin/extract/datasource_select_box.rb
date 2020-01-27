# frozen_string_literal: true

class Plugin::Extract::DatasourceSelectBox < Gtk::HierarchycalSelectBox
  def initialize(sources, &block)
    super(datasources, sources, &block)
  end

  def datasources
    (Plugin.filtering(:extract_datasources, {}) || [{}]).first.map do |id, source_name|
      [id, source_name.is_a?(String) ? source_name.split('/'.freeze) : source_name]
    end
  end

  def menu_pop(widget, _event)
    contextmenu = Gtk::ContextMenu.new
    contextmenu.register(_('データソース slugをコピー'), &method(:copy_slug))
    contextmenu.register(_('subscriberをコピー'), &method(:copy_subscriber))
    contextmenu.popup(widget, widget)
  end

  def copy_slug(_optional=nil, _widget=nil)
    data_sources = self.selection.to_enum(:selected_each).map {|_, _, iter|
      iter[ITER_ID]
    }
    Gtk::Clipboard.copy(data_sources.first.to_s)
  end

  def copy_subscriber(_optional=nil, _widget=nil)
    data_sources = self.selection.to_enum(:selected_each).map {|_, _, iter|
      iter[ITER_ID]
    }
    Gtk::Clipboard.copy(<<~'EOM' % {ds: data_sources.first.to_sym.inspect})
    subscribe(:extract_receive_message, %{ds}).each do |message|
      
    end
    EOM
  end
end
