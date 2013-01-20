# -*- coding: utf-8 -*-

require File.expand_path File.join(File.dirname(__FILE__), 'console_control')

Plugin.create :console do
  command(:console_open,
          name: 'コンソールを開く',
          condition: lambda{ |opt| true },
          visible: true,
          icon: Skin.get('console.png'),
          role: :pane) do |opt|
    if Plugin::GUI::Tab.cuscaded.has_key?(:console)
      Plugin::GUI::Tab.instance(:console).active!
      next end
    widget_result = ::Gtk::TextView.new
    scroll_result_v, scroll_result_h = gen_scrollbars(widget_result)
    widget_input = ::Gtk::TextView.new
    scroll_input_v, scroll_input_h = gen_scrollbars(widget_input)

    widget_result.set_editable(false)

    widget_result.set_size_request(0, 50)
    widget_input.set_size_request(0, 50)

    widget_result.buffer.insert(widget_result.buffer.start_iter, "mikutter console.\n下にRubyコードを入力して、Ctrl+Enterを押すと、ここに実行結果が表示されます\n")

    gen_tags(widget_result.buffer)

    widget_input.ssc('key_press_event'){ |widget, event|
      notice "console key press #{::Gtk::keyname([event.keyval ,event.state])}"
      if "Control + Return" == ::Gtk::keyname([event.keyval ,event.state])
        notice "console eval #{widget.buffer.text}"
        iter = widget_result.buffer.end_iter
        begin
          result = Kernel.instance_eval(widget.buffer.text)
          notice "console result #{result.inspect}"
          widget_result.buffer.insert(iter, ">>> ", "prompt")
          widget_result.buffer.insert(iter, "#{widget.buffer.text}\n", "echo")
          widget_result.buffer.insert(iter, "#{result.inspect}\n", "result")
        rescue Exception => e
          notice "console error occur #{e}"
          widget_result.buffer.insert(iter, ">>> ", "prompt")
          widget_result.buffer.insert(iter, "#{widget.buffer.text}\n", "echo")
          widget_result.buffer.insert(iter, "#{e.class}: ", "errorclass")
          widget_result.buffer.insert(iter, "#{e}\n", "error")
          widget_result.buffer.insert(iter, e.backtrace.join("\n") + "\n", "backtrace")
        end
        Delayer.new {
          if not widget_result.destroyed?
            widget_result.scroll_to_iter(iter, 0.0, false, 0, 1.0) end }
        true
      else
        false end }

    tab(:console, "コンソール") do
      set_icon Skin.get('console.png')
      set_deletable true
      nativewidget Plugin::Console::ConsoleControl.new().
        pack1(::Gtk::Table.new(2, 3).
              attach(widget_result, 0, 1, 0, 1, ::Gtk::FILL|::Gtk::SHRINK|::Gtk::EXPAND, ::Gtk::FILL|::Gtk::SHRINK|::Gtk::EXPAND).
              attach(scroll_result_h, 0, 1, 1, 2, ::Gtk::SHRINK|::Gtk::FILL, ::Gtk::FILL).
              attach(scroll_result_v, 1, 2, 0, 1, ::Gtk::FILL, ::Gtk::SHRINK|::Gtk::FILL),
              true, false).
        pack2(::Gtk::Table.new(2, 3).
              attach(widget_input, 0, 1, 0, 1, ::Gtk::FILL|::Gtk::SHRINK|::Gtk::EXPAND, ::Gtk::FILL|::Gtk::SHRINK|::Gtk::EXPAND).
              attach(scroll_input_h, 0, 1, 1, 2, ::Gtk::SHRINK|::Gtk::FILL, ::Gtk::FILL).
              attach(scroll_input_v, 1, 2, 0, 1, ::Gtk::FILL, ::Gtk::SHRINK|::Gtk::FILL),
              false, false)
      active!
    end
  end

  # _widget_ のためのスクロールバーを作って返す
  # ==== Args
  # [widget] Gtk::TextView
  # ==== Return
  # 縦スクロールバーと横スクロールバー
  def gen_scrollbars(widget)
    scroll_v = ::Gtk::VScrollbar.new
    scroll_h = ::Gtk::HScrollbar.new
    widget.set_scroll_adjustment(scroll_h.adjustment, scroll_v.adjustment)
    return scroll_v, scroll_h
  end

  # タグを作る
  # ==== Args
  # [buffer] Gtk::TextBuffer
  def gen_tags(buffer)
    type_strict buffer => ::Gtk::TextBuffer
    buffer.create_tag("prompt",
                      foreground_gdk: Gdk::Color.new(0, 0x6666, 0))
    buffer.create_tag("echo",
                      weight: Pango::FontDescription::WEIGHT_BOLD)
    buffer.create_tag("result",
                      foreground_gdk: Gdk::Color.new(0, 0, 0x6666))
    buffer.create_tag("errorclass",
                      foreground_gdk: Gdk::Color.new(0x6666, 0, 0))
    buffer.create_tag("error",
                      weight: Pango::FontDescription::WEIGHT_BOLD,
                      foreground_gdk: Gdk::Color.new(0x9999, 0, 0))
    buffer.create_tag("backtrace",
                      foreground_gdk: Gdk::Color.new(0x3333, 0, 0))
  end

end
