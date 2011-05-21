# -*- coding: utf-8 -*-

require 'gtk2'

miquire :mui, 'crud'
miquire :mui, 'cell_renderer_message'
miquire :mui, 'timeline_utils'
miquire :mui, 'pseudo_message_widget'
miquire :mui, 'postbox'

class Gtk::TimeLine < Gtk::VBox #Gtk::ScrolledWindow
  include Gtk::TimeLineUtils

  class InnerTL < Gtk::CRUD
    attr_accessor :postbox
    type_register('GtkInnerTL')

    def self.current_tl
      ctl = @@current_tl and @@current_tl.toplevel.focus.get_ancestor(Gtk::TimeLine::InnerTL) rescue nil
      ctl if(ctl.is_a?(Gtk::TimeLine::InnerTL))
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
      ctl = InnerTL.current_tl
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

  attr_reader :tl

  addlinkrule(URI.regexp(['http','https'])){ |url, widget|
    Gtk::TimeLine.openurl(url)
  }

  def self.get_active_mumbles
    if Gtk::TimeLine::InnerTL.current_tl
      InnerTL.current_tl.get_active_messages
    else
      [] end end

  @@tls = WeakSet.new

  def initialize
    super
    @@tls << @tl = InnerTL.new
    @tl.postbox = postbox
    scrollbar = Gtk::VScrollbar.new(@tl.vadjustment)
    closeup(postbox).pack_start(Gtk::HBox.new.pack_start(@tl).closeup(scrollbar))
    @tl.model.set_sort_column_id(2, order = Gtk::SORT_DESCENDING)
    @tl.set_size_request(100, 100)
    @tl.get_column(0).sizing = Gtk::TreeViewColumn::FIXED
    scroll_to_top_anime = false
    @tl.ssc(:scroll_event){ |this, e|
      case e.direction
      when Gdk::EventScroll::UP
        this.vadjustment.value -= this.vadjustment.step_increment
      when Gdk::EventScroll::DOWN
        this.vadjustment.value += this.vadjustment.step_increment end
      false }
    @tl.ssc(:expose_event){
      emit_expose_miraclepainter
      false }
    @tl.vadjustment.ssc(:value_changed, @tl){ |this|
        emit_expose_miraclepainter
        if(scroll_to_zero? and not(scroll_to_top_anime))
          scroll_to_top_anime = true
          scroll_speed = 4
          Gtk.timeout_add(25){
            if not(@tl.destroyed?)
              @tl.vadjustment.value -= (scroll_speed *= 2)
              scroll_to_top_anime = @tl.vadjustment.value > 0.0 end } end
      false } end

  def block_add(message)
    type_strict message => Message
    if not @tl.destroyed?
      raise "id must than 1 but specified #{message[:id].inspect}" if message[:id] <= 0
      if(!any?{ |m| m[:id] == message[:id] })
        scroll_to_zero_lator! if @tl.vadjustment.value == 0.0
        iter = @tl.model.append
        iter[0] = message[:id].to_s
        iter[1] = message
        iter[2] = message.modified.to_i
        sid = @tl.cell_renderer_message.miracle_painter(message).ssc(:modified, @tl){ |mb|
          if not @tl.destroyed?
          @tl.model.each{ |model, path, iter|
            if iter[0].to_i == message[:id]
              @tl.queue_draw
              break end }
          else
            @tl.cell_renderer_message.miracle_painter(message).signal_handler_disconnect(sid) end
          false } end end
    self end

  def each(index=1)
    @tl.model.each{ |model,path,iter|
      yield(iter[index]) } end

  def clear
    @tl.model.clear
    self end

  def add_retweets(messages)
    messages.each{ |message|
      if not include?(message.retweet_source)
        block_add(message.retweet_source)
      end
    }
  end

  def modified(message)
    type_strict message => Message
    mpi = get_iter_message_by(message)
    if(mpi)
      model, path, iter = mpi
      iter[2] = message.modified.to_i
      @tl.model.rows_reordered(path, iter, [0]) end
    self end

  # _message_ が新たに _user_ のお気に入りに追加された時に呼ばれる
  def favorite(user, message)
    self
  end

  # _message_ が _user_ のお気に入りから削除された時に呼ばれる
  def unfavorite(user, message)
    self
  end

  # つぶやきが削除されたときに呼ばれる
  def remove_if_exists_all(messages)
    messages.each{ |message|
      mpi = get_iter_message_by(message)
      @tl.model.remove(mpi[2]) if mpi } end

  def get_iter_message_by(message)
    type_strict message => Message
    id = message[:id].to_i
    @tl.model.to_enum(:each).find{ |mpi| mpi[2][0].to_i == id } end

  def destroyed?
    @tl.destroyed? or @tl.model.destroyed? end

  private

  def emit_expose_miraclepainter
    @exposing_miraclepainter ||= []
    if @tl.visible_range
      current, last = @tl.visible_range.map{ |path| @tl.model.get_iter(path) }
      messages = Set.new
      while current[0].to_i >= last[0].to_i
        messages << current[1]
        break if not current.next! end
      (messages - @exposing_miraclepainter).each{ |exposed|
        @tl.cell_renderer_message.miracle_painter(exposed).signal_emit(:expose_event) }
      @exposing_miraclepainter = messages end end

  def postbox
    @postbox ||= Gtk::VBox.new end

  def scroll_to_zero_lator!
    @scroll_to_zero_lator = true end

  def scroll_to_zero?
    result = (defined?(@scroll_to_zero_lator) and @scroll_to_zero_lator)
    @scroll_to_zero_lator = false
    result end

  Delayer.new{
    plugin = Plugin::create(:core)
    plugin.add_event(:message_modified){ |message|
      ObjectSpace.each_object(Gtk::TimeLine){ |tl|
        tl.modified(message) if not(tl.destroyed?) and tl.include?(message) } }
    plugin.add_event(:destroyed){ |messages|
      ObjectSpace.each_object(Gtk::TimeLine){ |tl|
        tl.remove_if_exists_all(messages) } }
  }

  Gtk::RC.parse_string <<EOS
style "timelinestyle"
{
  GtkTreeView::vertical-separator = 0
  GtkTreeView::horizontal-separator = 0
}
widget "*.timeline" style "timelinestyle"
EOS

end
