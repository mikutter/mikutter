# -*- coding: utf-8 -*-

miquire :core, 'plugin'

require 'gtk2'

=begin rdoc
プラグインに、簡単に設定ファイルを定義する機能を提供する。
以下の例は、このクラスを利用してプラグインの設定画面を定義する例。
  Plugin.create(:test) do
    settings("設定") do
      boolean "チェックする", :test_check
    end
  end

settingsの中身は、 Plugin::Setting のインスタンスの中で実行される。
つまり、 Plugin::Setting のインスタンスメソッドは、 _settings{}_ の中で実行できるメソッドと同じです。
例ではbooleanメソッドを呼び出して、真偽値を入力させるウィジェットを配置させるように定義している
(チェックボックス)。明確にウィジェットを設定できるわけではなくて、値の意味を定義するだけなので、
前後関係などに影響されてウィジェットが変わる場合があるかも。
=end
class Plugin::Setting < Gtk::VBox

  # 複数行テキスト
  # ==== Args
  # [label] ラベル
  # [config] 設定のキー
  def multitext(label, config)
    container = Gtk::HBox.new(false, 0)
    input = Gtk::TextView.new
    input.wrap_mode = Gtk::TextTag::WRAP_CHAR
    input.border_width = 2
    input.accepts_tab = false
    input.editable = true
    input.width_request = HYDE
    input.buffer.text = Listener[config].get || ''
    container.pack_start(Gtk::Label.new(label), false, true, 0) if label
    container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(input), true, true, 0)
    input.buffer.ssc('changed'){ |widget|
      Listener[config].set widget.text }
    closeup container
    container
  end

  # 特定範囲の数値入力
  # ==== Args
  # [label] ラベル
  # [config] 設定のキー
  # [min] 最低値。これより小さい数字は入力できないようになる
  # [max] 最高値。これより大きい数字は入力できないようになる
  def adjustment(name, config, min, max)
    container = Gtk::HBox.new(false, 0)
    container.pack_start(Gtk::Label.new(name), false, true, 0)
    adj = Gtk::Adjustment.new((Listener[config].get or min), min*1.0, max*1.0, 1.0, 5.0, 0.0)
    spinner = Gtk::SpinButton.new(adj, 0, 0)
    adj.signal_connect('value-changed'){ |widget, e|
      Listener[config].set widget.value.to_i
      false
    }
    closeup container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(spinner), true, true, 0)
    container
  end

  # 真偽値入力
  # ==== Args
  # [label] ラベル
  # [config] 設定のキー
  def boolean(label, config)
    input = Gtk::CheckButton.new(label)
    input.active = Listener[config].get
    input.signal_connect('toggled'){ |widget|
      Listener[config].set widget.active? }
    closeup input
    input end

  # ファイルを選択する
  # ==== Args
  # [label] ラベル
  # [config] 設定のキー
  # [current] 初期のディレクトリ
  def fileselect(label, config, current=Dir.pwd)
    container = input(label, config)
    input = container.children.last.children.first
    button = Gtk::Button.new('参照')
    container.pack_start(button, false)
    button.signal_connect('clicked'){ |widget|
      dialog = Gtk::FileChooserDialog.new("Open File",
                                          widget.get_ancestor(Gtk::Window),
                                          Gtk::FileChooser::ACTION_OPEN,
                                          nil,
                                          [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                                          [Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT])
      dialog.current_folder = File.expand_path(current)
      if dialog.run == Gtk::Dialog::RESPONSE_ACCEPT
        Listener[config].set dialog.filename
        input.text = dialog.filename
      end
      dialog.destroy
    }
    container
  end

  # 一行テキストボックス
  # ==== Args
  # [label] ラベル
  # [config] 設定のキー
  def input(label, config)
    container = Gtk::HBox.new(false, 0)
    input = Gtk::Entry.new
    input.text = Listener[config].get || ""
    container.pack_start(Gtk::Label.new(label), false, true, 0) if label
    container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(input), true, true, 0)
    input.signal_connect('changed'){ |widget|
      Listener[config].set widget.text }
    closeup container
    container
  end

  # 一行テキストボックス(非表示)
  # ==== Args
  # [label] ラベル
  # [config] 設定のキー
  def inputpass(label, config)
    container = Gtk::HBox.new(false, 0)
    input = Gtk::Entry.new
    input.visibility = false
    input.text = Listener[config].get
    container.pack_start(Gtk::Label.new(label), false, true, 0) if label
    container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(input), true, true, 0)
    input.signal_connect('changed'){ |widget|
      Listener[config].set widget.text }
    closeup container
    container
  end

  # 複数テキストボックス
  # 任意個の項目を入力させて、配列で受け取る。
  # ==== Args
  # [label] ラベル
  # [config] 設定のキー
  def multi(label, config)
    settings(label) do
      container, box = Gtk::HBox.new(false, 0), Gtk::VBox.new(false, 0)
      input_ary = []
      btn_add = Gtk::Button.new(Gtk::Stock::ADD)
      array_converter = lambda {
        c = Listener[config].get || []
        (c.is_a?(Array) ? c : [c]).select(&ret_nth) }
      add_button = lambda { |content|
        input = Gtk::Entry.new
        input.text = content.to_s
        input.ssc(:changed) { |w|
          Listener[config].set w.parent.children.map(&:text).select(&ret_nth) }
        input.ssc('focus_out_event'){ |w|
          w.parent.remove(w) if w.text.empty?
          false }
        box.closeup input
        input }
      input_ary = array_converter.call.each(&add_button)
      btn_add.ssc(:clicked) { |w|
        w.get_ancestor(Gtk::Window).set_focus(add_button.call("").show)
        false }
      container.pack_start(box, true, true, 0)
      container.pack_start(Gtk::Alignment.new(1.0, 1.0, 0, 0).add(btn_add), false, true, 0)
      closeup container
      container
    end
  end

  # 設定のグループ。関連の強い設定をカテゴライズできる。
  # ==== Args
  # [title] ラベル
  # [&block] ブロック
  def settings(title)
    group = Gtk::Frame.new.set_border_width(8)
    if(title.is_a?(Gtk::Widget))
      group.set_label_widget(title)
    else
      group.set_label(title) end
    box = Plugin::Setting.new.set_border_width(4)
    box.instance_eval(&Proc.new)
    closeup group.add(box)
    group
  end

  # 〜についてダイアログを出すためのボタン。押すとダイアログが出てくる
  # ==== Args
  # [label] ラベル
  # [options]
  #   設定値。以下のキーを含むハッシュ。
  #   _:name_ :: ソフトウェア名
  #   _:version_ :: バージョン
  #   _:copyright_ :: コピーライト
  #   _:comments_ :: コメント
  #   _:license_ :: ライセンス
  #   _:website_ :: Webページ
  #   _:logo_ :: ロゴ画像のフルパス
  #   _:authors_ :: 作者の名前。通常Twitter screen name（Array）
  #   _:artists_ :: デザイナとかの名前。通常Twitter screen name（Array）
  #   _:documenters_ :: ドキュメントかいた人とかの名前。通常Twitter screen name（Array）
  def about(label, options={})
    about = Gtk::Button.new("#{Environment::NAME} について")
    about.signal_connect("clicked"){
      dialog = Gtk::AboutDialog.new.show
      options.each { |key, value|
        dialog.__send__("#{key}=", about_converter[key][value]) }
      dialog.signal_connect('response') { dialog.destroy } }
    closeup about
    about end

  # フォントを決定させる。押すとフォント、サイズを設定するダイアログが出てくる。
  # ==== Args
  # [label] ラベル
  # [config] 設定のキー
  def font(label, config)
    closeup container = Gtk::HBox.new(false, 0).add(Gtk::Label.new(label).left).closeup(fontselect(label, config))
    container end

  # 色を決定させる。押すと色を設定するダイアログが出てくる。
  # ==== Args
  # [label] ラベル
  # [config] 設定のキー
  def color(label, config)
    closeup container = Gtk::HBox.new(false, 0).add(Gtk::Label.new(label).left).closeup(colorselect(label, config))
    container end

  # フォントと色を決定させる。
  # ==== Args
  # [label] ラベル
  # [font] フォントの設定のキー
  # [color] 色の設定のキー
  def fontcolor(label, font, color)
    closeup container = font(label, font).closeup(colorselect(label, color))
    container end

  # 要素を１つ選択させる
  # ==== Args
  # [label] ラベル
  # [config] 設定のキー
  # [default]
  #   連想配列で、 _値_ => _ラベル_ の形式で、デフォルト値を与える。
  #   _block_ と同時に与えれられたら、 _default_ の値が先に入って、 _block_ は後に入る。
  # [&block] 内容
  def select(label, config, default = {})
    builder = Plugin::Setting::Select.new(default)
    builder.instance_eval(&Proc.new) if block_given?
    closeup container = builder.build(label, config)
    container end

  # 要素を複数個選択させる
  # ==== Args
  # [label] ラベル
  # [config] 設定のキー
  # [default]
  #   連想配列で、 _値_ => _ラベル_ の形式で、デフォルト値を与える。
  #   _block_ と同時に与えれられたら、 _default_ の値が先に入って、 _block_ は後に入る。
  # [&block] 内容
  def multiselect(label, config, default = {})
    builder = Plugin::Setting::MultiSelect.new(default)
    builder.instance_eval(&Proc.new) if block_given?
    closeup container = builder.build(label, config)
    container end

  private
  def about_converter
    Hash.new(ret_nth).merge!( :logo => lambda{ |value| Gtk::WebIcon.new(value).pixbuf rescue nil } ) end
  memoize :about_converter

  def colorselect(label, config)
    color = Listener[config].get
    button = Gtk::ColorButton.new((color and Gdk::Color.new(*color)))
    button.title = label
    button.signal_connect('color-set'){ |w|
      Listener[config].set w.color.to_a }
    button end

  def fontselect(label, config)
    button = Gtk::FontButton.new(Listener[config].get)
    button.title = label
    button.signal_connect('font-set'){ |w|
      Listener[config].set w.font_name }
    button end

end

require File.expand_path File.join(File.dirname(__FILE__), 'select')
require File.expand_path File.join(File.dirname(__FILE__), 'multiselect')
require File.expand_path File.join(File.dirname(__FILE__), 'listener')
