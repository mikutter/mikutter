# -*- coding: utf-8 -*-
require 'gtk2'
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'utils'))
miquire :mui, 'extension'
miquire :mui, 'contextmenu'

# CRUDなリストビューを簡単に実現するためのクラス
class Gtk::CRUD < Gtk::TreeView
  attr_accessor :creatable, :updatable, :deletable, :dialog_title
  type_register

  def initialize
    super()
    set_model(Gtk::ListStore.new(*column_schemer.flatten.map{|x| x[:type]}))
    @creatable = @updatable = @deletable = true
    set_columns
    # self.set_enable_search(true).set_search_column(1).set_search_equal_func{ |model, column, key, iter|
    #   not iter[column].include?(key) }
    handle_release_event
    handle_row_activated
  end

  def buttons(box_klass)
    box_klass.new(false, 4).closeup(create_button).closeup(update_button).closeup(delete_button) end

  def create_button
    if not defined? @create_button
      @create_button = Gtk::Button.new(Gtk::Stock::ADD)
      @create_button.ssc(:clicked) {
        record_create(nil, nil) } end
    @create_button end

  def update_button
    if not defined? @update_button
      @update_button = Gtk::Button.new(Gtk::Stock::EDIT)
      @update_button.ssc(:clicked) {
        record_update(nil, nil) } end
    @update_button end

  def delete_button
    if not defined? @delete_button
      @delete_button = Gtk::Button.new(Gtk::Stock::DELETE)
      @delete_button.ssc(:clicked) {
        record_delete(nil, nil) } end
    @delete_button end

  protected

  def handle_row_activated
    self.signal_connect("row-activated"){|view, path, column|
      if @editable and iter = view.model.get_iter(path)
        if record = popup_input_window((0...model.n_columns).map{|i| iter[i] })
          force_record_update(iter, record) end end }
  end

  def handle_release_event
    self.signal_connect('button_release_event'){ |widget, event|
      if (event.button == 3)
        menu_pop(self, event)
        true end }
  end

  def on_created(iter)
  end

  def on_updated(iter)
  end

  def on_deleted(iter)
  end

  private

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
    when kind == :active
      toggled = Gtk::CellRendererToggle.new
      toggled.signal_connect('toggled'){ |toggled, path|
        iter = model.get_iter(path)
        iter[index] = !iter[index]
        on_updated(iter) }
      toggled
    end
  end

  def column_schemer
    [{:kind => :active, :widget => :boolean, :type => TrueClass, :label => '表示'},
     {:kind => :text, :widget => :input, :type => String, :label => '名前'},
     {:type => Object, :widget => :message_picker},
    ].freeze
  end
  memoize :column_schemer

  def force_record_create(record)
    iter = model.append
    record.each_with_index{ |item, index|
      iter[index] = item }
    on_created(iter) end

  def force_record_update(iter, record)
    record.each_with_index{ |item, index|
      iter[index] = item }
    on_updated(iter) end

  def force_record_delete(iter)
    on_deleted(iter)
    model.remove(iter)
  end

  def record_create(optional, widget)
    if @creatable
      record = popup_input_window()
      if record
        force_record_create(record) end end end

  def record_update(optional, widget)
    if @updatable
      self.selection.selected_each {|model, path, iter|
        record = popup_input_window((0...model.n_columns).map{|i| iter[i] })
        if record
          force_record_update(iter, record) end } end end

  def record_delete(optional, widget)
    if @deletable
      self.selection.selected_each {|model, path, iter|
        if Gtk::Dialog.confirm("本当に削除しますか？\n" +
                               "一度削除するともうもどってこないよ。")
          force_record_delete(iter) end } end end

  def menu_pop(widget, event)
    if(@creatable or @updatable or @deletable)
      contextmenu = Gtk::ContextMenu.new
      contextmenu.registmenu("新規作成", &method(:record_create)) if @creatable
      contextmenu.registmenu("編集", &method(:record_update)) if @updatable
      contextmenu.registmenu("削除", &method(:record_delete)) if @deletable
      contextmenu.popup(widget, widget) end end

  # 入力ウィンドウを表示する
  def popup_input_window(defaults = [])
    input = gen_popup_window_widget(defaults)
    Mtk.scrolled_dialog(dialog_title || "", input[:widget], self.toplevel || self, &input[:result]) end

  def gen_popup_window_widget(results = [])
    widget = Gtk::VBox.new
    column_schemer.flatten.each_with_index{ |scheme, index|
      case scheme[:widget]
      when :message_picker
        widget.closeup(Mtk.message_picker(lambda{ |new|
                                            if(new.nil?)
                                              results[index].freeze_ifn
                                            else
                                              results[index] = new.freeze_ifn end }))
      when nil
        ;
      else
        widget.closeup(Mtk.__send__((scheme[:widget] or :input), lambda{ |new|
                                   if(new.nil?)
                                     results[index].freeze_ifn
                                   else
                                     results[index] = new.freeze_ifn end },
                                 scheme[:label], *(scheme[:args].to_a or []))) end }
    { :widget => widget,
      :result => lambda{
        results } } end

end
