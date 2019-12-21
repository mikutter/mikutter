# -*- coding: utf-8 -*-

require 'net/http'

Plugin.create :bugreport do

  @bugreport_uri = Diva::URI('https://mikutter.hachune.net/')

  Delayer.new do |service|
    popup if crashed_exception.is_a? Exception
  rescue => e
    # バグ報告中にバグで死んだらつらいもんな
    error e
  end

  def popup
    alert_thread = if(Thread.main != Thread.current) then Thread.current end
    dialog = Gtk::Dialog.new("bug report")
    dialog.set_size_request(600, 400)
    dialog.window_position = Gtk::Window::POS_CENTER
    dialog.vbox.pack_start(main, true, true, 30)
    dialog.add_button(Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK)
    dialog.add_button(Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL)
    dialog.default_response = Gtk::Dialog::RESPONSE_OK
    quit = lambda{
      dialog.hide_all.destroy
      Gtk.main_iteration_do(false)
      if alert_thread
        alert_thread.run
      else
        Gtk.main_quit
      end }
    dialog.signal_connect("response"){ |widget, response|
      if response == Gtk::Dialog::RESPONSE_OK
        send
      else
        File.delete(File.expand_path(File.join(Environment::TMPDIR, 'mikutter_error'))) rescue nil
        File.delete(File.expand_path(File.join(Environment::TMPDIR, 'crashed_exception'))) rescue nil end
      quit.call }
    dialog.signal_connect("destroy") {
      false
    }
    dialog.show_all
    if(alert_thread)
      Thread.stop
    else
      Gtk::main
    end
  end

  def imsorry
    _("%{mikutter} が突然終了してしまったみたいで ヽ('ω')ﾉ三ヽ('ω')ﾉもうしわけねぇもうしわけねぇ")%{mikutter: Environment::NAME}+"\n"+
      _('OKボタンを押したら、自動的に以下のテキストが送られます。これがバグを直すのにとっても役に立つんですよ。よかったら送ってくれません？')
  end

  def main
    Gtk::VBox.new(false, 0).
      closeup(Gtk::IntelligentTextview.new(imsorry)).
      pack_start(Gtk::ScrolledWindow.
                 new.set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_ALWAYS).
                 add(Gtk::IntelligentTextview.new(backtrace)))
  end

  def send
    Thread.new do
      exception = crashed_exception
      m = exception.backtrace.first.match(/(.+?):(\d+)/)
      crashed_file, crashed_line = m[1], m[2]
      param = {
        'backtrace' => JSON.generate(exception.backtrace.map{ |msg| msg.gsub(FOLLOW_DIR, '{MIKUTTER_DIR}') }),
        'file' => crashed_file.gsub(FOLLOW_DIR, '{MIKUTTER_DIR}'),
        'line' => crashed_line,
        'exception_class' => exception.class,
        'description' => exception.to_s,
        'ruby_version' => RUBY_VERSION,
        'rubygtk_version' => Gtk::BINDING_VERSION.join('.'),
        'platform' => RUBY_PLATFORM,
        'url' => 'exception',
        'version' => Environment::VERSION
      }
      case exception
      when TypeStrictError
        param['causing_value'] = exception.value
      end
      http = Net::HTTP.new(@bugreport_uri.host, @bugreport_uri.port)
      http.use_ssl = @bugreport_uri.scheme == 'https'

      req = Net::HTTP::Post.new(@bugreport_uri.path)
      req.set_form_data(param)
      res = http.request(req)

      File.delete(File.expand_path(File.join(Environment::TMPDIR, 'mikutter_error'))) rescue nil
      File.delete(File.expand_path(File.join(Environment::TMPDIR, 'crashed_exception'))) rescue nil
      Plugin.activity :system, _("エラー報告を送信しました。ありがとう♡")
      Plugin.call :send_bugreport, param
    rescue Timeout::Error, StandardError => e
      Plugin.activity :system, _("ﾋﾟｬｱｱｱｱｱｱｱｱｱｱｱｱｱｱｱｱｱｱｱｱｱｱｱwwwwwwwwwwwwwwwwwwwwww")
      Plugin.activity :error, e.to_s, exception: e
    end
  end

  def backtrace
    "#{crashed_exception.class} #{crashed_exception.to_s}\n" +
      crashed_exception.backtrace.map{ |msg| msg.gsub(FOLLOW_DIR, '{MIKUTTER_DIR}') }.join("\n")
  end

  def crashed_exception
    @crashed_exception ||= object_get_contents(File.expand_path(File.join(Environment::TMPDIR, 'crashed_exception'))) rescue nil
  end

end
