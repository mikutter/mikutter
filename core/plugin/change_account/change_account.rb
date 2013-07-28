# -*- coding: utf-8 -*-

require File.join(File.dirname(__FILE__), "account_control")

Plugin.create :change_account do
  MikuTwitter::AuthenticationFailedAction.regist do |service, method = nil, url = nil, options = nil, res = nil|
    activity(:system, _("アカウントエラー (@{user})", user: service.user),
             description: _("ユーザ @{user} のOAuth 認証が失敗しました (@{response})\n設定から、認証をやり直してください。",
                            user: service.user, response: res))
    nil
  end

  settings _('アカウント情報') do
    listview = ::Plugin::ChangeAccount::AccountControl.new()
    Service.instances.each(&listview.method(:force_record_create))
    pack_start(Gtk::HBox.new(false, 4).
               add(listview).
               closeup(listview.buttons(Gtk::VBox)))
  end

end

