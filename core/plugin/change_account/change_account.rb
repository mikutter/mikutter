# -*- coding: utf-8 -*-

require File.join(File.dirname(__FILE__), "account_control")

Plugin.create :change_account do
  # トークン切れの警告
  MikuTwitter::AuthenticationFailedAction.register do |service, method = nil, url = nil, options = nil, res = nil|
    activity(:system, _("アカウントエラー (@{user})", user: service.user),
             description: _("ユーザ @{user} のOAuth 認証が失敗しました (@{response})\n設定から、認証をやり直してください。",
                            user: service.user, response: res))
    nil
  end

  # アカウント変更用の便利なコマンド
  command(:account_previous,
          name: _('前のアカウント'),
          condition: lambda{ |opt| Service.instances.size >= 2 },
          visible: true,
          role: :window) do |opt|
    index = Service.instances.index(Service.primary)
    if index
      max = Service.instances.size
      Service.set_primary(Service.instances[(max + index - 1) % max])
    elsif not Service.instances.empty?
      Service.set_primary(Service.instances.first) end
  end

  command(:account_forward,
          name: _('次のアカウント'),
          condition: lambda{ |opt| Service.instances.size >= 2 },
          visible: true,
          role: :window) do |opt|
    index = Service.instances.index(Service.primary)
    if index
      Service.set_primary(Service.instances[(index + 1) % Service.instances.size])
    elsif not Service.instances.empty?
      Service.set_primary(Service.instances.first) end
  end

  filter_command do |menu|
    Service.each do |service|
      user = service.user_obj
      slug = "switch_account_to_#{user.idname}".to_sym
      menu[slug] = {
        slug: slug,
        exec: -> options {},
        plugin: @name,
        name: _('@%{screen_name}(%{name}) に切り替える'.freeze) % {
          screen_name: user.idname,
          name: user[:name] },
        condition: -> options {},
        visible: false,
        role: :window,
        icon: user[:profile_image_url] } end
    [menu] end

  # サブ垢は心の弱さ
  settings _('アカウント情報') do
    listview = ::Plugin::ChangeAccount::AccountControl.new()
    Service.instances.each(&listview.method(:force_record_create))
    pack_start(Gtk::HBox.new(false, 4).
               add(listview).
               closeup(listview.buttons(Gtk::VBox)))
  end

  ### 茶番

  # 茶番オブジェクトを新しく作る
  def sequence
    # 茶番でしか使わないクラスなので、チュートリアル時だけロードする
    require File.join(File.dirname(__FILE__), "interactive")
    Plugin::ChangeAccount::Interactive.generate end

  @sequence = {}

  def defsequence(name, &content)
    @sequence[name] = content end

  def jump_seq(name)
    if defined? @sequence[name]
      store(:tutorial_sequence, name)
      notice "sequence move to #{name}"
      if @sequence.has_key? name
        @sequence[name].call
      else
        @sequence[:first].call
      end end end

  def request_token(reset = false)
    if !@request_token || reset
      twitter = MikuTwitter.new
      twitter.consumer_key = Environment::TWITTER_CONSUMER_KEY
      twitter.consumer_secret = Environment::TWITTER_CONSUMER_SECRET
      @request_token = twitter.request_oauth_token end
    @request_token end

  defsequence :first do
    sequence.
      say(_('インストールお疲れ様！')).
      say(_('はじめまして！私はマスコットキャラクターのみくったーちゃん。よろしくね。まずはTwitterアカウントを登録しようね。')).
      next{ jump_seq :register_account }
  end

  defsequence :register_account do
    if not Service.to_a.empty?
      jump_seq :achievement
      next
    end

    window = Plugin.filtering(:gui_get_gtk_widget, Plugin::GUI::Window.instance(:default)).first
    shell = window.children.first.children.first.children[1]
    eventbox = Gtk::EventBox.new
    container = Gtk::HBox.new(false)
    code_entry = Gtk::Entry.new
    decide_button = Gtk::Button.new(_("確定"))
    shell.add(eventbox.
              add(container.
                  closeup(Gtk::Label.new(_("コードを入力→"))).
                  add(code_entry).
                  closeup(decide_button).center).show_all)
    code_entry.ssc(:activate){
      decide_button.clicked if not decide_button.destroyed?
      false }
    decide_button.ssc(:clicked){
      eventbox.sensitive = false
      Thread.new{
        access_token = request_token.get_access_token(oauth_token: request_token.token,
                                                      oauth_verifier: code_entry.text)
        Service.add_service(access_token.token, access_token.secret)
      }.next{ |service|
        shell.remove(eventbox)
        Thread.new{
          sleep 2
          sequence.
          say(_('おっと。初めてアカウントを登録したから実績が解除されちゃったね。')).next{ jump_seq :achievement } }
      }.trap{ |error|
        error error
        shell.remove(eventbox)
        response = if error.is_a?(Net::HTTPResponse)
                     error
                   elsif error.is_a?(OAuth::Unauthorized)
                     error.request
                   end
        if response
          case response.code
          when '401'
            sequence.say(_("コードが間違ってるみたい。URLを再生成するから、もう一度アクセスしなおしてね。\n(%{code} %{message})") % {code: response.code, message: response.message}).next{
              jump_seq :register_account }
          else
            sequence.say(_("何かがおかしいよ。\n(%{code} %{message})") % {code: response.code, message: response.message}).next{
              jump_seq :register_account }
          end
          break
        end
        sequence.say(_("何かがおかしいよ。\n(%{error})") % {error: error.to_s}).next{
          jump_seq :register_account }
      }.trap{ |error|
        error error
      }
      false
    }
    sequence.
      say(_("登録方法は、\n1. %{authorize_url} にアクセスする\n2. mikutterに登録したいTwitterアカウントでログイン\n3. 適当に進んでいって取得できる7桁のコードをこのウィンドウの一番上に入力\nだよ。") % {authorize_url: request_token(true).authorize_url}, nil)
  end

  defsequence :achievement do
    name = Service.primary.user_obj[:name]
    sequence.
      say(_('実績は、まだ %{name} さんが使ったことのない機能を、たまに教えてあげる機能だよ。') % {name: name}).
      next{ jump_seq :final }
  end

  defsequence :final do
    sequence.
      say(_('……ちょっと短いけど、今私が教えてあげることはこれくらいかな？ Twitter をするために %{mikutter} をインストールしてくれたんだもんね。') % {mikutter: Environment::NAME}).
      say(_('これから少しずつ使い方を教えてあげるからね。それじゃ、またねー。')).
      next{ jump_seq :complete }
  end

  achievement = nil

  defsequence :complete do
    achievement.take! if achievement
  end

  defachievement(:tutorial,
                 description: _("mikutterのチュートリアルを見た"),
                 hidden: true
                 ) do |ach|
    seq = at(:tutorial_sequence)
    if not(seq or Service.instances.empty?)
      ach.take!
    else
      achievement = ach
      request_token if Service.to_a.empty?
      if seq
        sequence.
          say(_("前回の続きから説明するね")).
          next{ jump_seq(seq) }
      else
        jump_seq(:first) end end end

end
