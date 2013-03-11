# -*- coding: utf-8 -*-

miquire :mui, 'timeline', 'tree_view_pretty_scroll', 'dark_matter_prification'
miquire :lib, 'bsearch'
miquire :lib, 'uithreadonly'
require 'gtk2'

class Gtk::TimeLine::InnerTL < Gtk::CRUD

  include UiThreadOnly
  include Gtk::TreeViewPrettyScroll
  include Gtk::InnerTLDarkMatterPurification

  attr_writer :force_retrieve_in_reply_to
  attr_accessor :postbox, :imaginary
  type_register('GtkInnerTL')

  # TLの値を返すときに使う
  Record = Struct.new(:id, :message, :order, :miracle_painter)

  MESSAGE_ID = 0
  MESSAGE = 1
  ORDER = 2
  MIRACLE_PAINTER = 3

  def self.current_tl
    ctl = @@current_tl and @@current_tl.toplevel.focus.get_ancestor(Gtk::TimeLine::InnerTL) rescue nil
    ctl if(ctl.is_a?(Gtk::TimeLine::InnerTL) and not ctl.destroyed?)
  end

  # ==== Args
  # [from] 設定値を引き継ぐ元のInnerTL
  def initialize(from = nil)
    super()
    @force_retrieve_in_reply_to = :auto
    @@current_tl ||= self
    @id_dict = {} # message_id: iter
    @order = ->(m) { m.modified.to_i }
    self.name = 'timeline'
    set_headers_visible(false)
    set_enable_search(false)
    last_geo = nil
    selection.mode = Gtk::SELECTION_MULTIPLE
    get_column(0).set_sizing(Gtk::TreeViewColumn::AUTOSIZE)
    extend(from) if from
    set_events end

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
      {:kind => :text, :type => Integer},
      {:kind => :text, :type => Object}
    ].freeze
  end

  def get_order(m)
    type_strict m => Message
    @order.call(m) end

  # レコードの並び順を決めるブロックを登録する。ブロックは一つの Message を受け取り、数値を返す
  # ==== Args
  # [&block] 並び順を決めるブロック
  # ==== Return
  # self
  def set_order(&block)
    @order = block end

  def menu_pop(widget, event)
  end

  def handle_row_activated
  end

  def reply(message, options = {})
    ctl = Gtk::TimeLine::InnerTL.current_tl
    pb = nil
    if(ctl)
      options = options.dup
      options[:before_post_hook] = lambda{ |this|
        get_ancestor(Gtk::Window).set_focus(self) unless self.destroyed? }
      message = model.get_iter(message) if(message.is_a?(Gtk::TreePath))
      message = message[1] if(message.is_a?(Gtk::TreeIter))
      type_strict message => Message
      pb = Gtk::PostBox.new(message, options).show_all
      postbox.closeup(pb)
      pb.on_delete(&Proc.new) if block_given?
      get_ancestor(Gtk::Window).set_focus(pb.post)
      ctl.selection.unselect_all end
    pb end

  def add_postbox(i_postbox)
    reply(i_postbox.poster || Service.primary, i_postbox.options)
  end

  def set_cursor_to_display_top
    iter = model.iter_first
    set_cursor(iter.path, get_column(0), false) if iter end

  def get_active_messages
    get_active_iterators.map{ |iter| iter[1] } end

  def get_active_iterators
    selected = []
    if not destroyed?
      selection.selected_each{ |model, path, iter|
        selected << iter } end
    selected end

  def get_active_pathes
    selected = []
    if not destroyed?
      selection.selected_each{ |model, path, iter|
        selected << path } end
    selected end

  # 選択範囲の並び順の最初と最後を含むRangeを返す
  def selected_range_byorder
    start, last = visible_range
    start_record, last_record = get_record(start), get_record(last)
    Range.new(last_record[2], start_record[2]) if (start_record and last_record)
  end

  # _message_ のレコードの _column_ 番目のカラムの値を _value_ にセットする。
  # 成功したら _value_ を返す
  def update!(message, column, value)
    iter = get_iter_by_message(message)
    if iter
      iter[column] = value
      value end end

  # タイムラインの内容を全て削除する
  # ==== Return
  # self
  def clear
    deleted = @id_dict
    @id_dict = {}
    deleted.values.each{ |iter| iter[MIRACLE_PAINTER].destroy }
    model.clear end

  # _path_ からレコードを取得する。なければnilを返す。
  def get_record(path)
    iter = model.get_iter(path)
    if iter
      Record.new(iter[0].to_i, iter[1], iter[2], iter[3]) end end

  # _message_ に対応する Gtk::TreePath を返す。なければnilを返す。
  def get_path_by_message(message)
    get_path_and_iter_by_message(message)[1] end

  # _message_ に対応する値の構造体を返す。なければnilを返す。
  def get_record_by_message(message)
    path = get_path_and_iter_by_message(message)[1]
    get_record(path) if path end

  def force_retrieve_in_reply_to
    if(:auto == @force_retrieve_in_reply_to)
      UserConfig[:retrieve_force_mumbleparent]
    else
      @force_retrieve_in_reply_to end end

  # IDとGtk::TreeIterの対を登録する
  # ==== Args
  # [id] メッセージID
  # [iter] Gtk::TreeIter
  # ==== Return
  # self
  def set_id_dict(iter)
    id = iter[MESSAGE_ID].to_i
    if not @id_dict.has_key?(id)
      @id_dict[id] = iter
      iters = @id_dict
      iter[MIRACLE_PAINTER].signal_connect(:destroy) {
        iters.delete(id)
        false } end
    self end


  # 別の InnerTL が自分をextend()した時に呼ばれる
  def extended
    if @destroy_child_miraclepainters and signal_handler_is_connected?(@destroy_child_miraclepainters)
      signal_handler_disconnect(@destroy_child_miraclepainters) end end

  private

  # self に _from_ の内容をコピーする
  # ==== Args
  # [from] InnerTL
  # ==== Return
  # self
  def extend(from)
    @force_retrieve_in_reply_to = from.instance_eval{ @force_retrieve_in_reply_to }
    @imaginary = from.imaginary
    from.extended
    from.model.each{ |from_model, from_path, from_iter|
      iter = model.append
      iter[MESSAGE_ID] = from_iter[MESSAGE_ID]
      iter[MESSAGE] = from_iter[MESSAGE]
      iter[ORDER] = from_iter[ORDER]
      iter[MIRACLE_PAINTER] = from_iter[MIRACLE_PAINTER].set_tree(self)
      set_id_dict(iter) }
    self
  end

  def set_events
    @destroy_child_miraclepainters = signal_connect(:destroy) {
      notice "destroy child miracle painters"
      model.each{ |m, p, iter|
        iter[MIRACLE_PAINTER].destroy }
    }
    signal_connect(:focus_in_event){
      @@current_tl.selection.unselect_all if not(@@current_tl.destroyed?) and @@current_tl and @@current_tl != self
      @@current_tl = self
      
      false } end

  # _message_ に対応する Gtk::TreeIter を返す。なければnilを返す。
  def get_iter_by_message(message)
    get_path_and_iter_by_message(message)[2] end

  # _message_ から [model, path, iter] の配列を返す。見つからなかった場合は空の配列を返す。
  def get_path_and_iter_by_message(message)
    id = message[:id].to_i
    if @id_dict[id]
      if @id_dict[id][MIRACLE_PAINTER].destroyed?
        warn "destroyed miracle painter in cache (##{id})"
        @id_dict.delete(id)
        []
      else
        [model, @id_dict[id].path, @id_dict[id]] end
    else
      [] end end

end
