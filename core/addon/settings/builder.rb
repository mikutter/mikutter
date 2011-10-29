# -*- coding: utf-8 -*-

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
    input.buffer.text = UserConfig[config] || ''
    container.pack_start(Gtk::Label.new(label), false, true, 0) if label
    container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(input), true, true, 0)
    input.buffer.ssc('changed'){ |widget|
      UserConfig[config] = widget.text }
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
    adj = Gtk::Adjustment.new((UserConfig[config] or min), min*1.0, max*1.0, 1.0, 5.0, 0.0)
    spinner = Gtk::SpinButton.new(adj, 0, 0)
    spinner.wrap = true
    adj.signal_connect('value-changed'){ |widget, e|
      UserConfig[config] = widget.value.to_i
      false
    }
    closeup container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(spinner), true, true, 0)
    container
  end

  # 真偽値入力
  # ==== Args
  # [label] ラベル
  # [config] 設定のキー
  def boolean(label, key)
    input = Gtk::CheckButton.new(label)
    input.active = UserConfig[key]
    input.signal_connect('toggled'){ |widget|
      UserConfig[key] = widget.active? }
    closeup input
    input end

  # ファイルを選択する
  # ==== Args
  # [label] ラベル
  # [config] 設定のキー
  # [current] 初期のディレクトリ
  def fileselect(label, key, current=Dir.pwd)
    container = input = nil
    Mtk.input(key, label){ |c, i|
      container = c
      input = i }
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
        UserConfig[key] = dialog.filename
        input.text = dialog.filename
      end
      dialog.destroy
    }
    closeup container
    container
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

  private
  def about_converter
    Hash.new(ret_nth).merge!( :logo => lambda{ |value| Gtk::WebIcon.new(value).pixbuf rescue nil } ) end
  memoize :about_converter

end
