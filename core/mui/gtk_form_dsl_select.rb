# -*- coding: utf-8 -*-
require 'mui/gtk_form_dsl'

class Gtk::FormDSL::Select
  def initialize(parent_dslobj, values = [], mode: :auto)
    @parent_dslobj = parent_dslobj
    @options = values.to_a.freeze
    @mode = mode
  end

  def mode
    if @mode == :auto
      has_widget? ? :radio : :combo
    else
      @mode
    end
  end

  # セレクトボックスに要素を追加する
  # ==== Args
  # [value] 選択されたらセットされる値
  # [label] ラベル。 _&block_ がなければ使われる。文字列。
  # [&block] Plugin::Settings のインスタンス内で評価され、そのインスタンスが内容として使われる
  def option(value, label = nil, &block)
    if block
      widget = @parent_dslobj.create_inner_setting.set_border_width(4)
      widget.instance_eval(&block)
      @options += [[value, label, widget].freeze]
    else
      @options += [[value, label].freeze]
    end
    @options.freeze
    self
  end

  # 項目として、ウィジェットを持っているかを返す。
  # ==== Return
  # ウィジェットを持っているなら真
  def has_widget?
    not @options.all?{ |option| option.last.is_a? String }
  end

  # optionメソッドで追加された項目をウィジェットに組み立てる
  # ==== Args
  # [label] ラベル。文字列。
  # [config_key] 設定のキー
  # ==== Return
  # ウィジェット
  def build(label, config_key)
    case mode
    when :radio
      group = Gtk::Frame.new.set_border_width(8)
      group.set_label(label)
      group.add(build_box(config_key))
      group
    when :combo
      Gtk::HBox.new(false, 0).add(Gtk::Label.new(label).left).closeup(build_combobox(config_key))
    end
  end

  def method_missing(*args, &block)
    @parent_dslobj.method_missing(*args, &block)
  end

  private

  def build_box(config_key)
    box = Gtk::VBox.new
    group = Gtk::RadioButton.new

    options = @options
    options.each{ |value, face, setting|
      radio = nil
      if (not setting) and face.is_a? String
        box.closeup radio = Gtk::RadioButton.new(group, face)
      elsif setting.is_a? Gtk::FormDSL
        if face.is_a? String
          container = Gtk::Table.new(2, 2)
          radio = Gtk::RadioButton.new(group)
          container.attach(radio, 0, 1, 0, 1, Gtk::FILL, Gtk::FILL)
          container.attach(Gtk::Label.new(face).left, 1, 2, 0, 1, Gtk::SHRINK|Gtk::FILL, Gtk::FILL)
          container.attach(setting, 1, 2, 1, 2, Gtk::FILL|Gtk::SHRINK|Gtk::EXPAND, Gtk::FILL|Gtk::SHRINK|Gtk::EXPAND)
          box.closeup container
        else
          container = Gtk::HBox.new
          radio = Gtk::RadioButton.new(group)
          box.closeup container.closeup(radio).add(setting)
        end
      end
      if radio
        radio.ssc(:toggled, &generate_toggled_listener(config_key, value, setting))
        radio.active = @parent_dslobj[config_key] == value
        setting.sensitive = radio.active? if setting.is_a? Gtk::Widget
      end
    }
    box
  end

  # すべてテキストなら、コンボボックスで要素を描画する
  def build_combobox(config_key)
    input = Gtk::ComboBox.new(true)
    @options.each{ |t|
      input.append_text(t.last) }
    input.active = (@options.index{ |i| i.first.to_s == @parent_dslobj[config_key].to_s } || 0)
    @parent_dslobj[config_key] = @options[input.active].first
    input.ssc(:changed){ |widget|
      @parent_dslobj[config_key] = @options[widget.active].first
      false }
    input
  end

  def generate_toggled_listener(config_key, value, setting=nil)
    if setting.is_a? Gtk::Widget
      ->(widget) do
        @parent_dslobj[config_key] = value if widget.active?
        setting.sensitive = widget.active?
        false
      end
    else
      ->(widget) do
        @parent_dslobj[config_key] = value if widget.active?
        false
      end
    end
  end
end
