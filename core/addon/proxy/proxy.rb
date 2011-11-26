# -*- coding: utf-8

require 'net/http'

module Net
  class <<HTTP
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
    memoize :get_env_proxy_settings
  end
end

Module.new do

  def self.boot
    plugin = Plugin::create(:proxy)
    plugin.add_event(:boot) { |service|
      Plugin.call(:setting_tab_regist, settings, "プロキシ")
    }
    UserConfig.connect(:proxy_enabled) { |key, new_val, before_val, id|
      #UserStreamを使っているなら繋ぎなおさせる
      if UserConfig[:realtime_rewind]
        Thread.new {
          UserConfig[:realtime_rewind] = false
          sleep(3)
          UserConfig[:realtime_rewind] = true
        }
      end
    }
  end

  def self.settings
    box = Gtk::VBox.new(false, 8)

    radio_tag = radio_specify = Gtk::RadioButton.new('自分で設定する')
    radio_envval = Gtk::RadioButton.new(radio_tag, '環境変数の設定を使う')
    radio_disable = Gtk::RadioButton.new(radio_tag, 'プロキシを使わない')

    case UserConfig[:proxy_enabled]
    when :specify
      radio_specify.active = true
    when :disable
      radio_disable.active = true
    else
      radio_envval.active = true end

    box.
      closeup(gen_group(:specify, radio_specify)).
      closeup(gen_group(:envval, radio_envval)).
      closeup(gen_record(:disable, radio_disable))
  end

  def self.gen_record(name, radio)
    radio.signal_connect('toggled'){ |widget|
      UserConfig[:proxy_enabled] = name if widget.active? }
    radio
  end

  def self.gen_group(name, radio)
    eventbox = __send__("gen_#{name}_ev")
    radio.signal_connect('toggled'){ |widget|
      UserConfig[:proxy_enabled] = name if widget.active?
      eventbox.sensitive = widget.active? }
    eventbox.sensitive = UserConfig[:proxy_enabled] == name
    Mtk::group(radio, eventbox)
  end

  def self.gen_specify_ev
    sv = Mtk.input(:proxy_server, "サーバ")
    pt = Mtk.input(:proxy_port, "ポート")
    us = Mtk.input(:proxy_user, "ユーザ")
    pw = Mtk.input(:proxy_password, "パスワード")
    ct = Mtk.boolean(:proxy_cert, "ユーザ認証が必要")

    auth_group = Mtk::group(ct, us, pw)
    UserConfig.connect(:proxy_cert){ |key, new_val, before_val, id|
      us.sensitive = pw.sensitive = new_val }

    Gtk::EventBox.new.add(Gtk::VBox.new(false, 8).closeup(sv).closeup(pt).closeup(auth_group))
  end

  def self.gen_envval_ev
    env_getter = lambda{ |index|
      lambda{|x| Net::HTTP.get_env_proxy_settings[index].to_s } }
    sv = Mtk.input(env_getter[0], "サーバ"){|c,i|i.sensitive = false}
    pt = Mtk.input(env_getter[1], "ポート"){|c,i|i.sensitive = false}
    us = Mtk.input(env_getter[2], "ユーザ"){|c,i|i.sensitive = false}
    pw = Mtk.input(env_getter[3], "パスワード"){|c,i|i.sensitive = false}
    Gtk::EventBox.new.add(Gtk::VBox.new(false, 8).closeup(sv).closeup(pt).closeup(us).closeup(pw))
  end

  boot
end
