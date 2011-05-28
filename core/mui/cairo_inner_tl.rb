# -*- coding: utf-8 -*-

miquire :mui, 'timeline'

class Gtk::TimeLine::InnerTL < Gtk::CRUD
  attr_accessor :postbox
  type_register('GtkInnerTL')

  def self.current_tl
    ctl = @@current_tl and @@current_tl.toplevel.focus.get_ancestor(Gtk::TimeLine::InnerTL) rescue nil
    ctl if(ctl.is_a?(Gtk::TimeLine::InnerTL) and not ctl.destroyed?)
  end

  def initialize
    super
    @@current_tl ||= self
    self.name = 'timeline'
    set_headers_visible(false)
    set_enable_search(false)
    last_geo = nil
    selection.mode = Gtk::SELECTION_MULTIPLE
    get_column(0).set_sizing(Gtk::TreeViewColumn::AUTOSIZE)
    signal_connect(:focus_in_event){
      @@current_tl.selection.unselect_all if not(@@current_tl.destroyed?) and @@current_tl and @@current_tl != self
      @@current_tl = self
      false } end

  def cell_renderer_message
    @cell_renderer_message ||= Gtk::CellRendererMessage.new()
  end

  def column_schemer
    [ {:renderer => lambda{ |x,y|
          cell_renderer_message.tree = self
          cell_renderer_message
        },
        :kind => :message_id, :widget => :text, :type => String, :label => ''},
      {:kind => :text, :widget => :text, :type => Message},
      {:kind => :text, :widget => :text, :type => Integer}
    ].freeze
  end

  def menu_pop(widget, event)
  end

  def handle_row_activated
  end

  def reply(message, options = {})
    ctl = Gtk::TimeLine::InnerTL.current_tl
    if(ctl)
      message = model.get_iter(message) if(message.is_a?(Gtk::TreePath))
      message = message[1] if(message.is_a?(Gtk::TreeIter))
      type_strict message => Message
      postbox.closeup(pb = Gtk::PostBox.new(message, options).show_all)
      pb.on_delete(&Proc.new) if block_given?
      get_ancestor(Gtk::Window).set_focus(pb.post)
      ctl.selection.unselect_all end
    self end

  def get_active_messages
    get_active_iterators.map{ |iter| iter[1] } end

  def get_active_iterators
    selected = []
    selection.selected_each{ |model, path, iter|
      selected << iter }
    selected end

  def get_active_pathes
    selected = []
    selection.selected_each{ |model, path, iter|
      selected << path }
    selected end

end
