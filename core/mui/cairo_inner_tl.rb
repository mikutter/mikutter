# -*- coding: utf-8 -*-

miquire :mui, 'timeline'

class Gtk::TimeLine::InnerTL < Gtk::CRUD
  attr_accessor :postbox
  type_register('GtkInnerTL')

  # TLの値を返すときに使う
  Record = Struct.new(:id, :message, :created, :miracle_painter)

  MESSAGE_ID = 0
  MESSAGE = 1
  CREATED = 2
  MIRACLE_PAINTER = 3

  def self.current_tl
    ctl = @@current_tl and @@current_tl.toplevel.focus.get_ancestor(Gtk::TimeLine::InnerTL) rescue nil
    ctl if(ctl.is_a?(Gtk::TimeLine::InnerTL) and not ctl.destroyed?)
  end

  def initialize
    super
    @path_record = []
    @@current_tl ||= self
    self.name = 'timeline'
    set_headers_visible(false)
    set_enable_search(false)
    last_geo = nil
    selection.mode = Gtk::SELECTION_MULTIPLE
    get_column(0).set_sizing(Gtk::TreeViewColumn::AUTOSIZE)
    init_signal_hooks
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
      {:kind => :text, :type => Integer},
      {:kind => :text, :type => Object}
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

  # 選択範囲の時刻(UNIX Time)の最初と最後を含むRangeを返す
  def selected_range_bytime
    start, last = visible_range
    Range.new(get_record(last).created, get_record(start).created)
  end

  # _message_ のレコードの _column_ 番目のカラムの値を _value_ にセットする。
  # 成功したら _value_ を返す
  def update!(message, column, value)
    iter = get_iter_by_message(message)
    if iter
      iter[column] = value
      node = @path_record.rassoc(message)
      if node
        node[2] = Record.new(iter[0].to_i, iter[1], iter[2], iter[3])
      else
        add_iter(iter) end
      value end end

  # _path_ からレコードを取得する
  def get_record(path)
    record = sorted_path_record[-path.indices.first - 1][2]
    if record
      record
    else
      iter = model.get_iter(path)
      Record.new(iter[0].to_i, iter[1], iter[2], iter[3]) end end

  # _message_ に対応する Gtk::TreePath を返す
  def get_path_by_message(message)
    get_path_and_iter_by_message(message)[1] end

  # _message_ に対応する値の構造体を返す。Gtk::TreeIterに関わるメソッドはできるだけ減らしましょう！
  def get_record_by_message(message)
    node = @path_record.rassoc(message)
    if(node)
      node[2]
    else
      path = get_path_and_iter_by_message(message)[1]
      if path
        record = get_record(path)
        @path_record.unshift([nil, record.message, record])
        record end end end

  def sorted_path_record
    @path_record = @path_record.sort_by{ |n| n[2].created } end

  # model.appendで生成したイテレータにデータを格納し終わったら、それを引数に呼ぶといいですよ
  def add_iter(iter)
    @path_record.unshift([nil, iter[1], Record.new(iter[0].to_i, iter[1], iter[2], iter[3])])
    self end

  private

  # _message_ に対応する Gtk::TreeIter を返す
  def get_iter_by_message(message)
    get_path_and_iter_by_message(message)[2] end

  # _message_ から [model, path, iter] の配列を返す。見つからなかった場合は空の配列を返す。
  def get_path_and_iter_by_message(message)
    id = message[:id].to_i
    found = model.to_enum(:each).find{ |mpi| mpi[2][0].to_i == id }
    found || []  end

  def init_signal_hooks
    model.ssc(:row_deleted){ |path|
      if @path_record.size >= 200
        sorted_path_record.shift end
      false
    }
  end

end
