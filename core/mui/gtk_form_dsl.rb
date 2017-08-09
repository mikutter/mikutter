# -*- coding: utf-8 -*-

=begin rdoc
UIを定義するためのDSLメソッドをクラスに追加するmix-in。
現在の値（初期値）を返す[]メソッドと、値が変更された時に呼ばれる[]=メソッドを定義すること。
=end
module Gtk::FormDSL
  extend Memoist

  def initialize(*args)
    super
    if block_given?
      instance_eval(&Proc.new)
    end
  end

  # 複数行テキスト
  # ==== Args
  # [label] ラベル
  # [config] キー
  def multitext(label, config)
    container = Gtk::HBox.new(false, 0)
    input = Gtk::TextView.new
    input.wrap_mode = Gtk::TextTag::WRAP_CHAR
    input.border_width = 2
    input.accepts_tab = false
    input.editable = true
    input.width_request = HYDE
    input.buffer.text = self[config] || ''
    container.pack_start(Gtk::Label.new(label), false, true, 0) if label
    container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(input), true, true, 0)
    input.buffer.ssc(:changed){ |widget|
      self[config] = widget.text
      false
    }
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
    adj = Gtk::Adjustment.new((self[config] or min).to_f, min.to_f, max.to_f, 1.0, 5.0, 0.0)
    spinner = Gtk::SpinButton.new(adj, 0, 0)
    adj.signal_connect(:value_changed){ |widget, e|
      self[config] = widget.value.to_i
      false
    }
    closeup container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(spinner), true, true, 0)
    container
  end

  # 真偽値入力
  # ==== Args
  # [label] ラベル
  # [config] キー
  def boolean(label, config)
    input = Gtk::CheckButton.new(label)
    input.active = self[config]
    input.signal_connect(:toggled){ |widget|
      self[config] = widget.active?
      false
    }
    closeup input
    input
  end

  # ファイルを選択する
  # ==== Args
  # [label] ラベル
  # [config] キー
  # [dir] 初期のディレクトリ
  def fileselect(label, config, _current=Dir.pwd, dir: _current, title: label.to_s)
    fsselect(label, config, dir: dir, action: Gtk::FileChooser::ACTION_OPEN, title: title)
  end

  # ファイルを選択する
  # ==== Args
  # [label] ラベル
  # [config] キー
  # [dir] 初期のディレクトリ
  def photoselect(label, config, _current=Dir.pwd, dir: _current, title: label.to_s)
    fs_photoselect(label, config, dir: dir, action: Gtk::FileChooser::ACTION_OPEN, title: title)
  end

  # ディレクトリを選択する
  # ==== Args
  # [label] ラベル
  # [config] 設定のキー
  # [current] 初期のディレクトリ
  def dirselect(label, config, _current=Dir.pwd, dir: _current, title: label.to_s)
    fsselect(label, config, dir: dir, action: Gtk::FileChooser::ACTION_SELECT_FOLDER, title: title)
  end

  # 一行テキストボックス
  # ==== Args
  # [label] ラベル
  # [config] キー
  def input(label, config)
    container = Gtk::HBox.new(false, 0)
    input = Gtk::Entry.new
    input.text = self[config] || ""
    container.pack_start(Gtk::Label.new(label), false, true, 0) if label
    container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(input), true, true, 0)
    input.signal_connect(:changed){ |widget|
      self[config] = widget.text
      false
    }
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
    input.text = self[config] || ''
    container.pack_start(Gtk::Label.new(label), false, true, 0) if label
    container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(input), true, true, 0)
    input.signal_connect(:changed){ |widget|
      self[config] = widget.text
      false
    }
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
        c = self[config] || []
        (c.is_a?(Array) ? c : [c]).compact }
      add_button = lambda { |content|
        input = Gtk::Entry.new
        input.text = content.to_s
        input.ssc(:changed) { |w|
          self[config] = w.parent.children.map(&:text).compact
          false
        }
        input.ssc(:focus_out_event){ |w|
          w.parent.remove(w) if w.text.empty?
          false
        }
        box.closeup input
        input
      }
      input_ary = array_converter.call.each(&add_button)
      btn_add.ssc(:clicked) { |w|
        w.get_ancestor(Gtk::Window).set_focus(add_button.call("").show)
        false
      }
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
    box = create_inner_setting.set_border_width(4)
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
    name_mapper = Hash.new{|h,k| k }
    name_mapper[:name] = :program_name
    about = Gtk::Button.new(label)
    about.signal_connect(:clicked){
      dialog = Gtk::AboutDialog.new.show
      options.each { |key, value|
        dialog.__send__("#{name_mapper[key]}=", about_converter[key][value])
      }
      dialog.signal_connect(:response){
        dialog.destroy
        false
      }
    }
    closeup about
    about
  end

  # フォントを決定させる。押すとフォント、サイズを設定するダイアログが出てくる。
  # ==== Args
  # [label] ラベル
  # [config] 設定のキー
  def font(label, config)
    closeup container = Gtk::HBox.new(false, 0).add(Gtk::Label.new(label).left).closeup(fontselect(label, config))
    container
  end

  # 色を決定させる。押すと色を設定するダイアログが出てくる。
  # ==== Args
  # [label] ラベル
  # [config] 設定のキー
  def color(label, config)
    closeup container = Gtk::HBox.new(false, 0).add(Gtk::Label.new(label).left).closeup(colorselect(label, config))
    container
  end

  # フォントと色を決定させる。
  # ==== Args
  # [label] ラベル
  # [font] フォントの設定のキー
  # [color] 色の設定のキー
  def fontcolor(label, font, color)
    closeup container = font(label, font).closeup(colorselect(label, color))
    container
  end

  # 要素を１つ選択させる
  # ==== Args
  # [label] ラベル
  # [config] 設定のキー
  # [default]
  #   連想配列で、 _値_ => _ラベル_ の形式で、デフォルト値を与える。
  #   _block_ と同時に与えれられたら、 _default_ の値が先に入って、 _block_ は後に入る。
  # [&block] 内容
  def select(label, config, default = {})
    builder = Gtk::FormDSL::Select.new(self, default)
    builder.instance_eval(&Proc.new) if block_given?
    closeup container = builder.build(label, config)
    container
  end

  # 要素を複数個選択させる
  # ==== Args
  # [label] ラベル
  # [config] 設定のキー
  # [default]
  #   連想配列で、 _値_ => _ラベル_ の形式で、デフォルト値を与える。
  #   _block_ と同時に与えれられたら、 _default_ の値が先に入って、 _block_ は後に入る。
  # [&block] 内容
  def multiselect(label, config, default = {})
    builder = Gtk::FormDSL::MultiSelect.new(self, default)
    builder.instance_eval(&Proc.new) if block_given?
    closeup container = builder.build(label, config)
    container
  end

  # settingsメソッドとSelectから内部的に呼ばれるメソッド。Groupの中に入れるGtkウィジェットを返す。
  # 戻り値は同時にこのmix-inをロードしている必要がある。
  def create_inner_setting
    self.new()
  end

  def method_missing_at_select_dsl(*args, &block)
    @plugin.__send__(*args, &block)
  end

  def method_missing(*args, &block)
    @plugin.__send__(*args, &block)
  end

  private

  def about_converter
    Hash.new(ret_nth).merge!( :logo => lambda{ |value| Gtk::WebIcon.new(value).pixbuf rescue nil } )
  end
  memoize :about_converter

  def colorselect(label, config)
    color = self[config]
    button = Gtk::ColorButton.new((color and Gdk::Color.new(*color)))
    button.title = label
    button.signal_connect(:color_set){ |w|
      self[config] = w.color.to_a }
    button
  end

  def fontselect(label, config)
    button = Gtk::FontButton.new(self[config])
    button.title = label
    button.signal_connect(:font_set){ |w|
      self[config] = w.font_name }
    button end

  def fsselect(label, config, dir: Dir.pwd, action: Gtk::FileChooser::ACTION_OPEN, title: label)
    container = input(label, config)
    input = container.children.last.children.first
    button = Gtk::Button.new(Plugin[:settings]._('参照'))
    container.pack_start(button, false)
    button.signal_connect(:clicked, &gen_fileselect_dialog_generator(title, action, dir, config: config){|result| input.text = result })
    container
  end

  def fs_photoselect(label, config, dir: Dir.pwd, action: Gtk::FileChooser::ACTION_OPEN, title: label, width: 64, height: 32)
    photo = Enumerator.new{|y| Plugin.filtering(:photo_filter, self[config], y) }.first || self[config]
    container = Gtk::HBox.new
    w_image = Gtk::Image.new(photo.load_pixbuf(width: width, height: height){|pb| w_image.pixbuf = pb unless w_image.destroyed?})
    image_container = Gtk::EventBox.new
    image_container.ssc(:button_press_event) do |w, event|
      Plugin.call(:open, photo) if event.button == 1
      false
    end
    image_container.ssc_atonce(:realize) do |this|
      this.window.set_cursor(Gdk::Cursor.new(Gdk::Cursor::HAND2))
      false
    end
    button = Gtk::Button.new(Plugin[:settings]._('参照'))

    image_container.add(w_image)
    container.pack_start(Gtk::Label.new(label), false, true, 0) if label
    container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(image_container), true).pack_start(button, false)
    pack_start(container, false)

    button.signal_connect(:clicked, &gen_fileselect_dialog_generator(title, action, dir, config: config){|result|
                            photo = Enumerator.new{|y|
                              Plugin.filtering(:photo_filter, result, y)
                            }.first
                            w_image.pixbuf = photo.load_pixbuf(width: width, height: height){|pb| w_image.pixbuf = pb unless w_image.destroyed?} })
    container
  end


  def gen_fileselect_dialog_generator(title, action, dir, config:, &result_callback)
    ->(widget) do
      dialog = Gtk::FileChooserDialog.new(title,
                                          widget.get_ancestor(Gtk::Window),
                                          action,
                                          nil,
                                          [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                                          [Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT])
      dialog.current_folder = File.expand_path(dir)
      dialog.ssc_atonce(:response, &gen_fs_dialog_response_callback(config, &result_callback))
      dialog.show_all
      false
    end
  end

  def gen_fs_dialog_response_callback(config, &result_callback)
    ->(widget, response_id) do
      case response_id
      when Gtk::Dialog::RESPONSE_ACCEPT
        self[config] = widget.filename
        result_callback.(widget.filename)
      end
      widget.destroy
    end
  end
end

miquire :mui, 'form_dsl_select', 'form_dsl_multi_select'
