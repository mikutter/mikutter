# -*- coding: utf-8 -*-
require_relative 'builder'
require_relative 'model/twitter_account'

Plugin.create(:twitter) do
  # トークン切れの警告
  MikuTwitter::AuthenticationFailedAction.register do |service, method = nil, url = nil, options = nil, res = nil|
    activity(:system, _("アカウントエラー (@{user})", user: service.user),
             description: _("ユーザ @{user} のOAuth 認証が失敗しました (@{response})\n設定から、認証をやり直してください。",
                            user: service.user, response: res))
    nil
  end

  account_setting(:twitter, _('Twitter')) do
    builder = Plugin::Twitter::Builder.new(
      Environment::TWITTER_CONSUMER_KEY,
      Environment::TWITTER_CONSUMER_SECRET)
    # label _("URLをクリックしてトークンを発行")
    link builder.authorize_url
    input "トークン", :token
    result = await_input

    builder.build(result[:token])
  end

end
