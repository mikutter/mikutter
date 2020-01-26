# frozen_string_literal: true

require 'gtk2'
require_relative '../utils'
require 'mui/gtk_extension'
require 'mui/gtk_contextmenu'

# CRUDなリストビューを簡単に実現するためのクラス
class Gtk::CompatListView < Gtk::TreeView
  extend Memoist

  attr_accessor :dialog_title
  type_register

  def initialize
    super()
    initialize_model
    set_columns
  end

  private

  def initialize_model
    set_model(Gtk::ListStore.new(*column_schemer.flatten.map{|x| x[:type]}))
  end

  def set_columns
    column_schemer.inject(0){ |index, scheme|
      if scheme.is_a? Array
        col = Gtk::TreeViewColumn.new(scheme.first[:label])
        col.resizable = scheme.first[:resizable]
        scheme.each{ |cell|
          if cell[:kind]
            cell_renderer = get_render_by(cell, index)
            col.pack_start(cell_renderer, cell[:expand])
            col.add_attribute(cell_renderer, cell[:kind], index) end
          index += 1 }
        append_column(col)
      else
        if(scheme[:label] and scheme[:kind])
          col = Gtk::TreeViewColumn.new(scheme[:label], get_render_by(scheme, index), scheme[:kind] => index)
          col.resizable = scheme[:resizable]
          append_column(col) end
        index += 1 end
      index }
  end

  def get_render_by(scheme, index)
    kind = scheme[:kind]
    renderer = scheme[:renderer]
    case
    when renderer
      if renderer.is_a?(Proc)
        renderer.call(scheme, index)
      else
        renderer.new end
    when kind == :text
      Gtk::CellRendererText.new
    when kind == :pixbuf
      Gtk::CellRendererPixbuf.new
    end
  end

  def column_schemer
    raise 'Override this method!'
  end
end
