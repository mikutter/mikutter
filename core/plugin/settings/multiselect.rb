# -*- coding: utf-8 -*-
require File.expand_path File.join(File.dirname(__FILE__), 'builder')
require File.expand_path File.join(File.dirname(__FILE__), 'select')

class Plugin::Settings::MultiSelect < Plugin::Settings::Select

  # optionメソッドで追加された項目をウィジェットに組み立てる
  # ==== Args
  # [label] ラベル。文字列。
  # [config] 設定のキー
  # ==== Return
  # ウィジェット
  def build(label, config)
    if has_widget?
      group = Gtk::Frame.new.set_border_width(8)
      group.set_label(label)
      group.add(build_box(Plugin::Settings::Listener[config]))
      group
    else
      group = Gtk::Frame.new.set_border_width(8).
        set_label(label)
      box = Plugin::Settings.new(@plugin).set_border_width(4).
        closeup(build_combobox(Plugin::Settings::Listener[config]))
      group.add(box)
    end end

  private

  def build_box(listener)
    box = Gtk::VBox.new

    options = @options
    options.each{ |value, face, setting|
      if (not setting) and face.is_a? String
        box.closeup check = Gtk::CheckButton.new(face)
      elsif setting.is_a? Plugin::Settings
        if face.is_a? String
          container = Gtk::Table.new(2, 2)
          check = Gtk::CheckButton.new
          container.attach(check, 0, 1, 0, 1, Gtk::FILL, Gtk::FILL)
          container.attach(Gtk::Label.new(face).left, 1, 2, 0, 1, Gtk::SHRINK|Gtk::FILL, Gtk::FILL)
          container.attach(setting, 1, 2, 1, 2, Gtk::FILL|Gtk::SHRINK|Gtk::EXPAND, Gtk::FILL|Gtk::SHRINK|Gtk::EXPAND)
          box.closeup container
        else
          container = Gtk::HBox.new
          check = Gtk::CheckButton.new
          box.closeup container.closeup(check).add(setting) end
      else
        raise ArgumentError, "multiselect option value should be instance of String or Plugin::Settings. but #{face.class} given (#{face.inspect})"
      end
      check.ssc(:toggled, &generate_toggled_listener(listener, value, setting))
      check.active = (listener.get || []).include? value
      setting.sensitive = check.active? if setting.is_a? Gtk::Widget }
    box end

  # すべてテキストなら、コンボボックスで要素を描画する
  def build_combobox(listener)
    container = Gtk::VBox.new
    state = listener.get || []
    @options.each{ |pair|
      value, face = *pair
      check = Gtk::CheckButton.new(face)
      check.active = state.include?(value)
      check.ssc(:toggled, &generate_toggled_listener(listener, value))
      container.closeup check }
    container end

  def generate_toggled_listener(listener, value, setting=nil)
    if setting.is_a? Gtk::Widget
      ->(widget) do
        if widget.active?
          listener.set(Set[value, *(listener.get || [])]) unless (listener.get || []).include?(value)
        else
          listener.set((listener.get || []) - [value]) end
        setting.sensitive = widget.active?
      false end
    else
      ->(widget) do
        if widget.active?
          listener.set(Set[value, *(listener.get || [])]) unless (listener.get || []).include?(value)
        else
          listener.set((listener.get || []) - [value]) end
        false end end end
end
