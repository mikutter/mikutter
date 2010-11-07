# -*- coding:utf-8 -*-
miquire :addon, 'addon'
miquire :core, 'config'
miquire :addon, 'settings'

Module.new do

  container = Gtk::VBox.new(false, 8)

  def self.event_maker
    lambda{ |service|
      yield(Gtk::Mumble.active_mumbles) if not Gtk::Mumble.active_mumbles.empty? } end

  def self.event_maker_each
    event_maker{ |mumbles|
      mumbles.each{ |mumble| yield mumble } } end

  shortcutkeys = [ ['つぶやきを投稿する', :mumble_post_key],
                   ['リプライ', :reply_write_key, event_maker{ |mumbles|
                      mumbles.first.gen_postbox(mumbles.first.to_message, :subreplies => mumbles) }],
                   ['公式リツイート', :retweet_key, event_maker_each(&lazy.to_message.retweet)],
                   ['ふぁぼる', :favorite_key, event_maker_each{ |m| m.to_message.favorite(!m.to_message.favorite?) }],
  ].freeze

  shortcutkeys.each{ |pair|
    container.closeup(Mtk.keyconfig(*pair[0..1])) }

  plugin = Plugin::create(:shortcutkey)

  service = nil

  plugin.add_event(:boot){ |srv|
    service = srv
    Plugin.call(:setting_tab_regist, container, 'ショートカットキー') }

  plugin.add_event(:keypress){ |key|
    shortcutkeys.each{ |definition|
      name, config, proc = definition
      if(UserConfig[config] == key) and proc
        proc.call(service) end } }

end
