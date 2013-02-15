# -*- coding: utf-8 -*-
require File.expand_path File.join(File.dirname(__FILE__), 'builder')

class Plugin::Settings::Select
  def initialize(values = [])
    @options = values.to_a.freeze end

  # セレクトボックスに要素を追加する
  # ==== Args
  # [value] 選択されたらセットされる値
  # [label] ラベル。 _&block_ がなければ使われる。文字列。
  # [&block] Plugin::Settings のインスタンス内で評価され、そのインスタンスが内容として使われる
  def option(value, label = nil)
    if block_given?
      widget = Plugin::Settings.new.set_border_width(4)
      widget.instance_eval(&Proc.new)
      @options += [[value, label, widget].freeze]
    else
      @options += [[value, label].freeze] end
    @options.freeze
    self end

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
    type_strict label => String, config => Symbol
    if has_widget?
      group = Gtk::Frame.new.set_border_width(8)
      group.set_label(label)
      group.add(build_box(Plugin::Settings::Listener[config]))
      group
    else
      Gtk::HBox.new(false, 0).add(Gtk::Label.new(label).left).closeup(build_combobox(Plugin::Settings::Listener[config])) end end

  private

  def build_box(listener)
    type_strict listener => Plugin::Settings::Listener
    box = Gtk::VBox.new
    group = Gtk::RadioButton.new

    options = @options
    box.instance_eval{
      options.each{ |value, face, setting|
        radio = nil
        if (not setting) and face.is_a? String
          closeup radio = Gtk::RadioButton.new(group, face)
        elsif setting.is_a? Plugin::Settings
          if face.is_a? String
            container = Gtk::Table.new(2, 2)
            radio = Gtk::RadioButton.new(group)
            container.attach(radio, 0, 1, 0, 1, Gtk::FILL, Gtk::FILL)
            container.attach(Gtk::Label.new(face).left, 1, 2, 0, 1, Gtk::SHRINK|Gtk::FILL, Gtk::FILL)
            container.attach(setting, 1, 2, 1, 2, Gtk::FILL|Gtk::SHRINK|Gtk::EXPAND, Gtk::FILL|Gtk::SHRINK|Gtk::EXPAND)
            closeup container
          else
            container = Gtk::HBox.new
            radio = Gtk::RadioButton.new(group)
            closeup container.closeup(radio).add(setting) end
        end
        if radio
          radio.signal_connect('toggled'){ |widget|
            listener.set value if widget.active?
            setting.sensitive = widget.active? if setting.is_a? Gtk::Widget }
          notice "#{listener.get.inspect} == #{value.inspect}"
          radio.active = listener.get == value
          face.sensitive = radio.active? if face.is_a? Gtk::Widget end } }
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
