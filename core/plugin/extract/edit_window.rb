# -*- coding: utf-8 -*-
require 'observer'
miquire :mui, 'hierarchycal_selectbox'
require_relative 'model/setting'
require_relative 'option_widget'

module Plugin::Extract
end

class  Plugin::Extract::EditWindow < Gtk::Window
  attr_reader :extract

  # ==== Args
  # [extract] 抽出タブ設定 (Plugin::Extract::Setting)
  # [plugin] プラグインのインスタンス (Plugin)
  def initialize(extract, plugin)
    @plugin = plugin
    @extract = extract
    super(_('%{name} - 抽出タブ - %{application_name}') % {name: name, application_name: Environment::NAME})
    add(Gtk::VBox.new().
        add(Gtk::Notebook.new.
            append_page(source_widget, Gtk::Label.new(_('データソース'))).
            append_page(condition_widget, Gtk::Label.new(_('絞り込み条件'))).
            append_page(option_widget, Gtk::Label.new(_('オプション')))).
        closeup(Gtk::EventBox.new().
                add(Gtk::HBox.new().
                    closeup(ok_button).right)))
    ssc(:destroy) do
      @extract.notify_update
      false
    end
    set_size_request 480, 320
    show_all end

  def name
    @extract.name end

  def sexp
    @extract.sexp end

  def id
    @extract.id end

  def sources
    @extract.sources end

  def slug
    @extract.slug end

  def sound
    @extract.sound end

  def popup
    @extract.popup end

  def order
    @extract.order end

  def icon
    @extract.icon end

  def source_widget
    datasources = (Plugin.filtering(:extract_datasources, {}) || [{}]).first.map do |id, source_name|
      [id, source_name.is_a?(String) ? source_name.split('/'.freeze) : source_name] end
    datasources_box = Gtk::HierarchycalSelectBox.new(datasources, sources){
      modify_value sources: datasources_box.selected.to_a }
    scrollbar = ::Gtk::VScrollbar.new(datasources_box.vadjustment)
    @source_widget ||= Gtk::HBox.new().
      add(datasources_box).
      closeup(scrollbar) end

  def condition_widget
    @condition_widget ||= Gtk::VBox.new().
      add(condition_form) end

  def condition_form
    @condition_form = Gtk::MessagePicker.new(sexp.freeze){
      modify_value sexp: @condition_form.to_a
    } end

  def option_widget
    Plugin::Extract::OptionWidget.new(@plugin, @extract) do
      input _('名前'), :name
      fileselect _('アイコン'), :icon, Skin.path
      settings _('通知') do
        fileselect _('サウンド'), :sound
        boolean _('ポップアップ'), :popup
      end
      select(_('並び順'), :order, Hash[Plugin.filtering(:extract_order, []).first.map{|o| [o.slug.to_s, o.name] }])
    end
  end

  def ok_button
    Gtk::Button.new(_('閉じる')).tap{ |button|
      button.ssc(:clicked){
        self.destroy } } end

  def refresh_title
    set_title _('%{name} - 抽出タブ - %{application_name}') % {name: name, application_name: Environment::NAME}
  end

  private

  def modify_value(new_values)
    @extract.merge(new_values)
    refresh_title
    @extract.notify_update
    self end

  def _(message)
    @plugin._(message) end

end
