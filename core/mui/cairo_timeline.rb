# -*- coding: utf-8 -*-

require 'gtk2'

class Gtk::TimeLine < Gtk::VBox
end

miquire :mui, 'crud'
miquire :mui, 'cell_renderer_message'
miquire :mui, 'timeline_utils'
miquire :mui, 'pseudo_message_widget'
miquire :mui, 'postbox'
miquire :mui, 'inner_tl'

class Gtk::TimeLine
  include Gtk::TimeLineUtils

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
    init_remover
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

  def each(index=1)
    @tl.model.each{ |model,path,iter|
      yield(iter[index]) } end

  def each_iter
    @tl.model.each{ |model,path,iter|
      yield(iter) } end

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
    path = get_path_by_message(message)
    if(path)
      iter = @tl.model.get_iter(path)
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
      path = get_path_by_message(message)
      @tl.model.remove(@tl.model.get_iter(path)) if path } end

  # _message_ に対応する _Gtk::TreePath_ を返す
  def get_path_by_message(message)
    type_strict message => Message
    id = message[:id].to_i
    found = @tl.model.to_enum(:each).find{ |mpi| mpi[2][0].to_i == id }
    found[1] if found  end

  def size
    @tl.model.to_enum(:each).inject(0){ |i, r| i + 1 } end

  def destroyed?
    @tl.destroyed? or @tl.model.destroyed? end

  protected

  def block_add(message)
    type_strict message => Message
    if not @tl.destroyed?
      raise "id must than 1 but specified #{message[:id].inspect}" if message[:id] <= 0
      if(!any?{ |m| m[:id] == message[:id] })
        case
        when message[:rule] == :destroy
          remove_if_exists_all([message])
        when message.retweet?
          add_retweets([messages])
        else
          _add(message) end end end
    self end

  private

  def _add(message)
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
      false }
    @remover_queue.push(message)
    self
  end

  def init_remover
    @timeline_max = 200
    @remover_queue = TimeLimitedQueue.new(1024, 1){ |messages|
      Delayer.new{
        if not destroyed?
          remove_count = size - timeline_max
          if remove_count > 0
            to_enum(:each_iter).to_a[-remove_count, remove_count].each{ |iter| @tl.model.remove(iter) } end end } } end

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
