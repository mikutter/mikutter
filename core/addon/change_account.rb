# -*- coding: utf-8 -*-
miquire :addon, 'addon'
miquire :addon, 'settings'
miquire :core, 'config'

Module.new do

  def self.boot
    plugin = Plugin::create(:friend_timeline)
    plugin.add_event(:boot){ |service|
      service.auth_confirm_func = method(:popup)
      Plugin.call(:setting_tab_regist, main_for_tab(service), 'アカウント情報') }
  end

  def self.popup(watch)
    result = [nil]
    alert_thread = if(Thread.main != Thread.current) then Thread.current end
    dialog = Gtk::Dialog.new(Environment::NAME + " ログイン")
    container, key, request_token = main(watch)
    dialog.set_size_request(600, 400)
    dialog.window_position = Gtk::Window::POS_CENTER
    dialog.vbox.pack_start(container, true, true, 30)
    dialog.add_button(Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK)
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
    dialog.signal_connect("response") do |widget, response|
      if response == Gtk::Dialog::RESPONSE_OK
        begin
          access_token = request_token.get_access_token(:oauth_token => request_token.token,
                                                        :oauth_verifier => key.text)
          result = [access_token.token, access_token.secret]
          quit.call
        rescue => e
          alert("暗証番号が違うみたいです\n\n#{e}")
        end
      else
        quit.call end end
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
    return *result
  end

  def self.main_for_tab(watch)
    decide = Gtk::Button.new('変更')
    attention = Gtk::Label.new("変更後は、#{Environment::NAME}を再起動した方がいいと思うよ！")
    attention.wrap = true
    decide.signal_connect("clicked"){
      token, secret = popup(watch)
      if token
        UserConfig[:twitter_token] = token
        UserConfig[:twitter_secret] = secret end }
    Gtk::VBox.new(false, 0).closeup(attention).closeup(decide)
  end

  def self.main(watch)
    goaisatsu = Gtk::VBox.new(false, 0)
    box = Gtk::VBox.new(false, 8)
    request_token = watch.request_oauth_token
    Delayer.new(Delayer::NORMAL, goaisatsu, request_token.authorize_url){ |w, url|
      w.closeup(Gtk::Mumble.new(Message.new(:message => hello(url), :system => true))).show_all }
    user, key_input = gen_input('暗証番号', true)
    box.closeup(goaisatsu).closeup(user)
    return box, key_input, request_token
  end

  def self.gen_input(label, visibility=true, default="")
    container = Gtk::HBox.new(false, 0)
    input = Gtk::Entry.new
    input.text = default
    input.visibility = visibility
    container.pack_start(Gtk::Label.new(label), false, true, 0)
    container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(input), true, true, 0)
    return container, input
  end

  def self.hello(url)
    first = if not at(:hello_first)
              "マスターったら、ツイッターまでみっくみくね！\n\n" end
    store(:hello_first, true)
    "#{first}ログインの手順:\n下のリンクをクリックして、ユーザ名などを入れてから許可するボタンを"+
      "押してください(クリックしても開かなかったら、アドレスバーにコピペだ！)。\n"+
      "#{url}\n表示された数字を「暗証番号」に入力してOKボタンを押してください。\n\n"+
      'すると、みっくみくにされます。'
  end

  boot
end

#Plugin::Ring.push Addon::ChangeAccount.new,[:boot]
