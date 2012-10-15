# -*- coding: utf-8 -*-

Plugin.create :change_account do

  def popup(watch, method = nil, url = nil, options = nil, res = nil)
    if(Thread.main == Thread.current)
      Delayer.event_lock{ _popup(watch) }
    else
      input = false
      result = nil
      Delayer.new{
        result = _popup(watch)
        input = true
      }
      while(!input)
        sleep(1) end
      notice "twitter token: #{result.inspect}"
      if result
        UserConfig[:twitter_authenticate_revision] = Environment::TWITTER_AUTHENTICATE_REVISION
        UserConfig[:twitter_token], UserConfig[:twitter_secret] = result end
      result end end

  def _popup(watch)
    result = [nil]
    main_windows = Plugin.filtering(:get_windows, Set.new).first
    alert_thread = if(Thread.main != Thread.current) then Thread.current end
    dialog = ::Gtk::Dialog.new(Environment::NAME + " ログイン")
    container, key, request_token = main(watch, dialog)
    dialog.set_size_request(600, 400)
    dialog.window_position = ::Gtk::Window::POS_CENTER
    dialog.vbox.pack_start(container, true, true, 30)
    dialog.add_button(::Gtk::Stock::OK, ::Gtk::Dialog::RESPONSE_OK)
    dialog.default_response = ::Gtk::Dialog::RESPONSE_OK
    quit = lambda{
      dialog.hide_all.destroy
      ::Gtk.main_iteration_do(false)
      main_windows.each{ |w| w.show }
      if alert_thread
        alert_thread.run
      else
        ::Gtk.main_quit end }
    dialog.signal_connect("response") do |widget, response|
      if response == ::Gtk::Dialog::RESPONSE_OK
        begin
          access_token = request_token.get_access_token(:oauth_token => request_token.token,
                                                        :oauth_verifier => key.text)
          UserConfig[:twitter_authenticate_revision] = Environment::TWITTER_AUTHENTICATE_REVISION
          UserConfig[:twitter_token], UserConfig[:twitter_secret] = access_token.token, access_token.secret
          result = [access_token.token, access_token.secret]
          quit.call
        rescue => e
          Mtk.alert("暗証番号が違うみたいです\n\n#{e}")
        end
      else
        quit.call end end
    dialog.signal_connect("destroy") {
      false
    }
    container.show
    dialog.show_all
    main_windows.each{ |w| w.hide }
    if(alert_thread)
      Thread.stop
    else
      ::Gtk::main end
    result end

  def main(watch, dialog)
    goaisatsu = ::Gtk::VBox.new(false, 0)
    box = ::Gtk::VBox.new(false, 8)
    request_token = watch.request_oauth_token
    goaisatsu.add(::Gtk::IntelligentTextview.new(hello(request_token.authorize_url)))
    user, key_input = gen_input('暗証番号', dialog, true)
    box.closeup(goaisatsu).closeup(user)
    return box, key_input, request_token
  end

  def gen_input(label, dialog, visibility=true, default="")
    container = ::Gtk::HBox.new(false, 0)
    input = ::Gtk::Entry.new
    input.text = default
    input.visibility = visibility
    input.signal_connect('activate') { |elm|
      dialog.response(::Gtk::Dialog::RESPONSE_OK) }
    container.pack_start(::Gtk::Label.new(label), false, true, 0)
    container.pack_start(::Gtk::Alignment.new(1.0, 0.5, 0, 0).add(input), true, true, 0)
    return container, input
  end

  def hello(url)
    "マスターったら、ツイッターまでみっくみくね！\n\n"+
    "ログインの手順:\n下のリンクをクリックして、ユーザ名などを入れてから許可するボタンを"+
      "押してください(クリックしても開かなかったら、アドレスバーにコピペだ！)。\n"+
      "#{url}\n表示された数字を「暗証番号」に入力してOKボタンを押してください。\n\n"+
      'すると、みっくみくにされます。'
  end

  on_reauthentication_dialog do |service|
    token, secret = popup(service)
    if token
      UserConfig[:twitter_authenticate_revision] = Environment::TWITTER_AUTHENTICATE_REVISION
      UserConfig[:twitter_token] = token
      UserConfig[:twitter_secret] = secret end
  end

  MikuTwitter::AuthenticationFailedAction.regist &method(:popup)
  settings 'アカウント情報' do
    closeup attention = ::Gtk::Label.new("変更後は、#{Environment::NAME}を再起動した方がいいと思うよ！")
    closeup decide = ::Gtk::Button.new('変更')
    attention.wrap = true
    decide.signal_connect("clicked"){
      Plugin.call(:reauthentication_dialog, Service.primary) }
  end

end

#Plugin::Ring.push Addon::ChangeAccount.new,[:boot]
