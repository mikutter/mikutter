# -*- coding: utf-8 -*-
miquire :mui, 'form_dsl', 'form_dsl_select', 'form_dsl_multi_select'

module Plugin::Gtk
  class DialogWindow < Gtk::Dialog
    # ダイアログを開く。このメソッドを直接利用せずに、Pluginのdialog DSLを利用すること。
    # ==== Args
    # [title:] ダイアログのタイトルバーに表示する内容(String)
    # [promise:] 入力が完了・中断された時に呼ばれるDeferedオブジェクト
    # [plugin:] 呼び出し元のPluggaloid Plugin
    # [default:] エレメントのデフォルト値。{キー: デフォルト値}のようなHash
    # [&proc] DSLブロック
    # ==== Return
    # 作成されたDialogのインスタンス
    def self.open(title:, promise:, plugin:, default:, &proc)
      window = new(plugin: plugin, title: title, promise: promise, default: default, &proc)
      window.show_all
      window
    end

    def initialize(title:, promise:, plugin:, default:, &proc)
      super(title)
      @plugin = plugin
      @container = DialogContainer.new(plugin, default.to_h.dup, &proc)
      @promise = promise
      set_size_request(640, 480)
      set_window_position(Gtk::Window::POS_CENTER)
      add_button(Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK)
      add_button(Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL)
      vbox.pack_start(@container)
      register_response_listener
    end

    private

    def register_response_listener
      ssc(:response) do |widget, response|
        case response
        when Gtk::Dialog::RESPONSE_OK
          if @container.wait?
            @container.run(Response::Ok.new(@container))
          else
            @promise.call(Response::Ok.new(@container)) if @promise
            @promise = nil
            destroy
          end
        else
          @promise.fail(Response::Cancel.new(@container)) if @promise
          @promise = nil
          destroy
        end
        true
      end
      ssc(:destroy) do
        @promise.fail(Response::Cancel.new(@container)) if @promise
        @promise = nil
        false
      end
    end

    module Response
      class Base
        def initialize(values)
          @values = values.to_h.freeze
        end

        def [](k)
          @values[k.to_sym]
        end

        def to_h
          @values.to_h
        end
      end

      class Ok < Base
        def ok? ; true end
        def state ; :ok end
      end

      class Cancel < Base
        def ok? ; false end
        def state ; :cancel end
      end

      class Close < Base
        def ok? ; false end
        def state ; :close end
      end
    end
  end

  class DialogContainer < Gtk::VBox
    EXIT = :exit

    include Gtk::FormDSL

    attr_reader :state

    # dialog DSLから利用するメソッド。
    # dialogウィンドウのエレメントの配置を、ユーザが次へボタンを押すまで中断する。
    # 次へボタンが押されたら、 その時点で各エレメントに入力された内容を格納した
    # Plugin::Gtk::DialogWindow::Response::Ok のインスタンスを返す
    def await_input
      Fiber.yield
    end

    # dialog DSLから利用するメソッド。
    # 初期値を動的に設定するためのメソッド。
    # {エレメントのキー: 値} のように書くことで、複数同時に設定できる。
    # 既に置かれたエレメントの内容がこのメソッドによって書き換わることはないので、
    # エレメントを配置する前に呼び出す必要がある。
    def set_value(v={})
      @values.merge!(v)
    end

    def create_inner_setting
      self.class.new(@plugin, @values)
    end

    def initialize(plugin, default=Hash.new)
      @plugin = plugin
      @state = :init
      @values = default
      @proc = Proc.new
      super()
      run
    end

    def run(response=nil)
      Delayer.new do
        case state
        when :init
          @fiber = Fiber.new do
            instance_eval(&@proc)
            EXIT
          end
          resume(response)
        when :wait
          children.each(&method(:remove))
          resume(response)
        end
      end
    end

    def resume(response)
      @state = :run
      result = @fiber.resume(response)
      show_all
      case result
      when EXIT
        @state = :exit
      else
        @state = :wait
      end
    end

    def wait?
      @state == :wait
    end

    def [](key)
      @values[key.to_sym]
    end

    def []=(key, value)
      @values[key.to_sym] = value
    end

    def to_h
      @values.dup
    end
  end
end
