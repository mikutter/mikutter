# -*- coding: utf-8 -*-
require 'observer'

module Plugin::Extract
end

class Plugin::Extract::EditWindow < Gtk::Window

  def initialize(extract, plugin)
    @plugin = plugin
    @extract = extract.dup.freeze
    super(_('%{name} - 抽出タブ - %{application_name}') % {name: name, application_name: Environment::NAME})
    add(Gtk::VBox.new().
        closeup(name_widget).
        add(Gtk::Notebook.new.
            append_page(source_widget, Gtk::Label.new(_('データソース'))).
            append_page(condition_widget, Gtk::Label.new(_('絞り込み条件')))).
        closeup(Gtk::EventBox.new().
                add(Gtk::HBox.new().
                    closeup(ok_button).right)))
    ssc(:destroy) do
      Plugin.call :extract_tab_update, self.to_h end
    show_all end

  def name
    @extract[:name] || "".freeze end

  def sexp
    if defined? @condition_form
      @condition_form.to_a
    else
      @extract[:sexp] end end

  def id
    @extract[:id] end

  def sources
    @extract[:sources] || [] end

  def slug
    @extract[:slug] end

  # extract の内容を返す
  # ==== Return
  # @extract の内容(Hash)
  def to_h
    { name: name,
      sexp: sexp,
      id: id,
      slug: slug,
      sources: sources }.freeze end

  # 名前入力ウィジェットを返す
  # ==== Return
  # Gtk::HBox.new
  def name_widget
    @name_widget ||= Gtk::HBox.new().
      closeup(Gtk::Label.new(_('名前'))).
      add(name_entry) end

  # 名前入力ボックス
  # ==== Return
  # Gtk::Entry
  def name_entry
    @name_entry ||= Gtk::Entry.new().tap { |name_entry|
      name_entry.set_text name
      name_entry.ssc(:changed){ |widget|
        modify_value name: widget.text.dup.freeze
        self.set_title _('%{name} - 抽出タブ - %{application_name}') % {name: name, application_name: Environment::NAME}
        false } } end

  def source_widget
    datasources = (Plugin.filtering(:extract_datasources, {}) || [{}]).first
    datasources_box = Gtk::SelectBox.new(datasources, sources.map(&:to_sym)){
      modify_value sources: datasources_box.selected }
    @source_widget ||= Gtk::VBox.new().
      add(datasources_box) end

  def condition_widget
    @condition_widget ||= Gtk::VBox.new().
      add(condition_form) end

  def condition_form
    @condition_form = Gtk::MessagePicker.new(sexp.freeze){
      modify_value sexp: @condition_form.to_a
    } end

  def ok_button
    Gtk::Button.new(_('閉じる')).tap{ |button|
      button.ssc(:clicked){
        self.destroy } } end

  private

  def modify_value(new_values)
    @extract = @extract.merge(new_values).freeze
    Plugin.call :extract_tab_update, self.to_h
    self end

  def _(message)
    @plugin._(message) end

end
