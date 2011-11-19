# -*- coding: utf-8 -*-
require File.expand_path File.join(File.dirname(__FILE__), 'builder')

class Plugin::Setting::Select
  def initialize(values = [])
    @options = values.to_a end

  # セレクトボックスに要素を追加する
  # ==== Args
  # [value] 選択されたらセットされる値
  # [label] ラベル。 _&block_ がなければ使われる。文字列。
  # [&block] Plugin::Setting のインスタンス内で評価され、そのインスタンスが内容として使われる
  def option(value, label = nil)
    if block_given?
      widget = Plugin::Setting.new.set_border_width(4)
      widget.instance_eval(&Proc.new)
      @options << [value, widget]
    else
      @options << [value, label] end end

  # 項目として、ウィジェットを持っているかを返す。
  # ==== Return
  # ウィジェットを持っているなら真
  def has_widget?
    not @options.all?{ |option| option.last.is_a? String } end

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
      group.add(build_box(Plugin::Setting::Listener[config]))
      group
    else
      Gtk::HBox.new(false, 0).add(Gtk::Label.new(label).left).closeup(build_combobox(Plugin::Setting::Listener[config])) end end

  private

  def build_box(listener)
    box = Gtk::VBox.new
    group = Gtk::RadioButton.new

    options = @options
    box.instance_eval{
      first = true
      options.each{ |value, face|
        radio = nil
        if face.is_a? String
          closeup radio = Gtk::RadioButton.new(group, face)
        elsif face.is_a? Plugin::Setting
          container = Gtk::HBox.new
          radio = Gtk::RadioButton.new(group)
          closeup container.closeup(radio).add(face)
        end
        radio.signal_connect('toggled'){ |widget|
          listener.set value if widget.active?
          face.sensitive = widget.active? if face.is_a? Gtk::Widget }
        radio.active = first || (listener.get == value)
        face.sensitive = radio.active? if face.is_a? Gtk::Widget
        first = false } }
    box end

  # すべてテキストなら、コンボボックスで要素を描画する
  def build_combobox(listener)
    input = Gtk::ComboBox.new(true)
    sorted = @options.map{ |o| o.first }.sort_by(&:to_s).freeze
    sorted.each{ |x|
      input.append_text(@options.assoc(x).last) }
    input.active = (sorted.index{ |i| i.to_s == listener.get.to_s } || 0)
    listener.set sorted[input.active]
    input.signal_connect('changed'){ |widget|
      listener.set sorted[widget.active]
      nil }
    input end
end
