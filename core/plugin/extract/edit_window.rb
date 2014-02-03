# -*- coding: utf-8 -*-

module Plugin::Extract
end

class Plugin::Extract::EditWindow < Gtk::Window
  def initialize(extract, plugin)
    @plugin = plugin
    @extract = extract.dup
    super(_('%{name} - 抽出タブ - %{application_name}') % {name: extract[:name], application_name: Environment::NAME})
    add(Gtk::VBox.new().
        closeup(name_widget).
        add(Gtk::HBox.new().
            closeup(source_widget).
            add(condition_widget)).
        closeup(Gtk::EventBox.new().
                add(Gtk::HBox.new().
                    closeup(ok_button).right)))
    show_all
  end

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
      name_entry.set_text @extract[:name]
      name_entry.ssc(:changed){ |widget|
        @extract[:name] = widget.text
        self.set_title _('%{name} - 抽出タブ - %{application_name}') % {name: @extract[:name], application_name: Environment::NAME}
        false } } end

  def source_widget
    @source_widget ||= Gtk::VBox.new().
      closeup(Gtk::Label.new(_('データソース'))).
      add(Gtk::SelectBox.new((Plugin.filtering(:extract_datasources, {}) || [{}]).first, []))
  end

  def condition_widget
    @condition_widget ||= Gtk::VBox.new().
      closeup(Gtk::Label.new(_('条件'))).
      add(condition_form) end

  def condition_form
    @condition_form = Gtk::MessagePicker.new(@extract[:sexp]) {
      # changed
    } end

  def ok_button
    Gtk::Button.new(_('閉じる')).tap{ |button|
      button.ssc(:clicked){
        self.destroy } } end

  private

  def _(message)
    @plugin._(message) end

end
