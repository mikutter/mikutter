# -*- coding: utf-8 -*-
miquire :mui, 'form_dsl_select', 'form_dsl'

class Gtk::FormDSL::MultiSelect < Gtk::FormDSL::Select

  # optionメソッドで追加された項目をウィジェットに組み立てる
  # ==== Args
  # [label] ラベル。文字列。
  # [config_key] 設定のキー
  # ==== Return
  # ウィジェット
  def build(label, config_key)
    if has_widget?
      group = Gtk::Frame.new.set_border_width(8)
      group.set_label(label)
      group.add(build_box(config_key))
      group
    else
      group = Gtk::Frame.new.set_border_width(8).
        set_label(label)
      box = @parent_klass.create_inner_setting.set_border_width(4).
        closeup(build_combobox(config_key))
      group.add(box)
    end
  end

  private

  def build_box(config_key)
    box = Gtk::VBox.new

    options = @options
    options.each{ |value, face, setting|
      if (not setting) and face.is_a? String
        box.closeup check = Gtk::CheckButton.new(face)
      elsif setting.is_a? Gtk::FormDSL
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
          box.closeup container.closeup(check).add(setting)
        end
      else
        raise ArgumentError, "multiselect option value should be instance of String or Gtk::FormDSL. but #{face.class} given (#{face.inspect})"
      end
      check.ssc(:toggled, &generate_toggled_listener(config_key, value, setting))
      check.active = (@parent_dslobj[config_key] || []).include? value
      setting.sensitive = check.active? if setting.is_a? Gtk::Widget
    }
    box
  end

  # すべてテキストなら、コンボボックスで要素を描画する
  def build_combobox(config_key)
    container = Gtk::VBox.new
    state = @parent_dslobj[config_key] || []
    @options.each{ |pair|
      value, face = *pair
      check = Gtk::CheckButton.new(face)
      check.active = state.include?(value)
      check.ssc(:toggled, &generate_toggled_listener(config_key, value))
      container.closeup check
    }
    container
  end

  def generate_toggled_listener(config_key, value, setting=nil)
    if setting.is_a? Gtk::Widget
      ->(widget) do
        if widget.active?
          @parent_dslobj[config_key] = Set[value, *(@parent_dslobj[config_key] || [])] unless (@parent_dslobj[config_key] || []).include?(value)
        else
          @parent_dslobj[config_key] = (@parent_dslobj[config_key] || []) - [value]
        end
        setting.sensitive = widget.active?
        false
      end
    else
      ->(widget) do
        if widget.active?
          @parent_dslobj[config_key] = Set[value, *(@parent_dslobj[config_key] || [])] unless (@parent_dslobj[config_key] || []).include?(value)
        else
          @parent_dslobj[config_key] = (@parent_dslobj[config_key] || []) - [value]
        end
        false
      end
    end
  end
end
