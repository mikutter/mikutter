# -*- coding: utf-8 -*-
Plugin.create :change_account do
  MikuTwitter::AuthenticationFailedAction.regist do |service, method = nil, url = nil, options = nil, res = nil|
    activity(:system, _("アカウントエラー (@{user})", user: service.user),
             description: _("ユーザ @{user} のOAuth 認証が失敗しました (@{response})\n設定から、認証をやり直してください。",
                            user: service.user, response: res))
    nil
  end

  
end
