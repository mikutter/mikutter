# -*- coding: utf-8 -*-
require 'gtk2'
require_relative '../utils'
miquire :mui, 'extension'
miquire :mui, 'contextmenu'
miquire :mui, 'compatlistview'

# CRUDなリストビューを簡単に実現するためのクラス
class Gtk::CRUD < Gtk::CompatListView
  attr_accessor :creatable, :updatable, :deletable
  type_register

  def initialize
    super()
    @creatable = @updatable = @deletable = true
    handle_release_event
    handle_row_activated
  end

  def buttons(box_klass)
    box_klass.new(false, 4).closeup(create_button).closeup(update_button).closeup(delete_button)
  end

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
    self.ssc(:row_activated){|view, path, column|
      if @updatable and iter = view.model.get_iter(path)
        if record = popup_input_window((0...model.n_columns).map{|i| iter[i] })
          force_record_update(iter, record) end end }
  end

  def handle_release_event
    self.ssc(:button_release_event){ |widget, event|
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

  def get_render_by(scheme, index)
    result = super
    if result
      result
    elsif scheme[:kind] == :active
      toggled = Gtk::CellRendererToggle.new
      toggled.ssc(:toggled) do |toggled, path|
        iter = model.get_iter(path)
        iter[index] = !iter[index]
        on_updated(iter)
        false
      end
      toggled
    end
  end

  def force_record_create(record)
    iter = model.model.append
    record.each_with_index{ |item, index|
      iter[index] = item }
    on_created(iter) end

  def force_record_update(iter, record)
    if defined? model.convert_iter_to_child_iter(iter)
      iter = model.convert_iter_to_child_iter iter end
    record.each_with_index{ |item, index|
      iter[index] = item }
    on_updated(iter) end

  def force_record_delete(iter)
    if defined? model.convert_iter_to_child_iter(iter)
      iter = model.convert_iter_to_child_iter iter end
    on_deleted(iter)
    model.model.remove(iter)
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
        if record and not model.destroyed?
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
      contextmenu.register("新規作成", &method(:record_create)) if @creatable
      contextmenu.register("編集", &method(:record_update)) if @updatable
      contextmenu.register("削除", &method(:record_delete)) if @deletable
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
