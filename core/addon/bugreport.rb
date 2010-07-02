miquire :addon, 'addon'
miquire :core, 'config'
miquire :addon, 'settings'

require 'net/http'

Module.new do

  def self.boot
    plugin = Plugin::create(:bugreport)
    plugin.add_event(:boot){ |service|
      popup if File.size? File.expand_path(File.join(Environment::TMPDIR, 'mikutter_error')) } end

  private

  def self.popup
    alert_thread = if(Thread.main != Thread.current) then Thread.current end
    dialog = Gtk::Dialog.new("bug report")
    container = main
    dialog.set_size_request(600, 400)
    dialog.window_position = Gtk::Window::POS_CENTER
    dialog.vbox.pack_start(container, true, true, 30)
    dialog.add_button(Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK)
    dialog.add_button(Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL)
    dialog.default_response = Gtk::Dialog::RESPONSE_OK
    quit = lambda{
      dialog.hide_all.destroy
      Gtk.main_iteration_do(false)
      Gtk::Window.toplevels.first.show
      if alert_thread
        alert_thread.run
      else
        Gtk.main_quit
      end }
    dialog.signal_connect("response"){ |widget, response|
      if response == Gtk::Dialog::RESPONSE_OK
        send
      else
        File.delete(File.expand_path(File.join(Environment::TMPDIR, 'mikutter_error'))) end
      quit.call }
    dialog.signal_connect("destroy") {
      false
    }
    container.show
    dialog.show_all
    Gtk::Window.toplevels.first.hide
    if(alert_thread)
      Thread.stop
    else
      Gtk::main
    end
  end

  def self.imsorry
    "#{Config::NAME} が突然終了してしまったみたいで ヽ('ω')ﾉ三ヽ('ω')ﾉもうしわけねぇもうしわけねぇ\n"+
      'OKボタンを押したら、自動的に以下のテキストが送られます。これがバグを直すのにとっても'+
      '役に立つんですよ。よかったら送ってくれません？'
  end

  def self.main
    Gtk::VBox.new(false, 0).
      closeup(Gtk::IntelligentTextview.new(imsorry)).
      pack_start(Gtk::ScrolledWindow.
                 new.set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_ALWAYS).
                 add(Gtk::IntelligentTextview.new(backtrace)))
  end

  def self.send
    Thread.new{
      begin
        Net::HTTP.start('mikutter.d.hachune.net'){ |http|
          param = encode_parameters({ 'backtrace' => backtrace,
                                      'svn' => revision,
                                      'ruby_version' => RUBY_VERSION,
                                      'platform' => RUBY_PLATFORM,
                                      'url' => 'bugreport',
                                      'version' => Environment::VERSION })
          http.post('/', param) }
        File.delete(File.expand_path(File.join(Environment::TMPDIR, 'mikutter_error')))
        Plugin::Ring::fire(:update, [nil, Message.new(:message => "エラー報告を送信しました。ありがとう♡",
                                                      :system => true)])
      rescue => e
        Plugin::Ring::fire(:update, [nil, Message.new(:message => "ごめんなさい。エラー通知通知すらバグってるみたいだわ\n\n#{e.to_s}",
                                                      :system => true)])
      end } end

  def self.revision
    begin
      open('|env LANG=C svn info').read.match(/Revision\s*:\s*(\d+)/)[1]
    rescue
      '' end end

  def self.backtrace
    file_get_contents(File.expand_path(File.join(Environment::TMPDIR, 'mikutter_error')))
  end

  def self.encode_parameters(params, delimiter = '&', quote = nil)
    if params.is_a?(Hash)
      params = params.map do |key, value|
        "#{escape(key)}=#{quote}#{escape(value)}#{quote}"
      end
    else
      params = params.map { |value| escape(value) }
    end
    delimiter ? params.join(delimiter) : params
  end

  def self.escape(value)
    URI.escape(value.to_s, /[^a-zA-Z0-9\-\.\_\~]/)
  end

end

# Plugin::Ring.push Addon::Bugreport.new,[:boot]
