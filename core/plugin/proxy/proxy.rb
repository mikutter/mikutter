# -*- coding: utf-8 -8

require 'net/http'

module Net
  class << HTTP
    extend Memoist

    alias new_org new
    def new(host, port=80, proxy_addr=nil, proxy_port=nil, proxy_user=nil, proxy_pass=nil)
      case UserConfig[:proxy_enabled]
      when :specify
        pu, pp = nil, nil
        pu, pp = UserConfig[:proxy_user], UserConfig[:proxy_password] if UserConfig[:proxy_cert]

        new_org(host, port, UserConfig[:proxy_server], UserConfig[:proxy_port].to_i, pu, pp)
      when :disable
        new_org(host, port)
      else
        new_org(host, port, *get_env_proxy_settings) end end

    def get_env_proxy_settings
      env_proxy_settings = (ENV["HTTP_PROXY"] || '').sub(/http:\/\//, '').split(/[@:]/)
      case(env_proxy_settings.size)
      when 2
        [env_proxy_settings[0], env_proxy_settings[1].to_i]
      when 4
        [env_proxy_settings[2], env_proxy_settings[3].to_i, env_proxy_settings[0], env_proxy_settings[1]]
      else
        [] end end
  end
end

Plugin::create(:proxy) do
  settings _("プロキシ") do
    select _("プロキシ"), :proxy_enabled do
      option :specify, _("自分で設定する") do
        input _("サーバ"), :proxy_server
        adjustment _("ポート"), :proxy_port, 1, 65535
        input _("ユーザ"), :proxy_user
        inputpass _("パスワード"), :proxy_password
        boolean _("ユーザ認証が必要"), :proxy_cert
      end
      option :disable, _("環境変数の設定を使う")
      option nil, _("プロキシを使わない")
    end
  end
end
