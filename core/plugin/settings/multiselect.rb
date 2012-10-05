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
      box = Plugin::Settings.new.set_border_width(4).
        closeup(build_combobox(Plugin::Settings::Listener[config]))
      group.add(box)
    end end

  private

  def build_box(listener)
    box = Gtk::VBox.new

    options = @options
    box.instance_eval{
      options.each{ |value, face|
        if face.is_a? String
          closeup check = Gtk::CheckButton.new(face)
        elsif face.is_a? Plugin::Settings
          container = Gtk::HBox.new
          check = Gtk::CheckButton.new
          closeup container.closeup(check).add(face)
        else
          raise ArgumentError, "multiselect option value should be instance of String or Plugin::Settings. but #{face.class} given (#{face.inspect})"
        end
        check.signal_connect('toggled'){ |widget|
          if widget.active?
            listener.set((listener.get || []) + [value])
          else
            listener.set((listener.get || []) - [value]) end
          face.sensitive = widget.active? if face.is_a? Gtk::Widget }
        check.active = (listener.get || []).include? value
        face.sensitive = check.active? if face.is_a? Gtk::Widget } }
    box end

  # すべてテキストなら、コンボボックスで要素を描画する
  def build_combobox(listener)
    container = Gtk::VBox.new
    state = listener.get || []
    @options.each{ |pair|
      node, value = *pair
      check = Gtk::CheckButton.new(value)
      check.active = state.include?(node)
      check.signal_connect('toggled'){ |widget|
        if widget.active?
          listener.set((listener.get || []) + [node])
        else
          listener.set((listener.get || []) - [node]) end }
      container.closeup check }
    container end
end
