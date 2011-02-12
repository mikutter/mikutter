# -*- coding:utf-8 -*-
miquire :addon, 'addon'
miquire :core, 'environment'
miquire :addon, 'settings'

Module.new do

  container = Gtk::VBox.new(false, 8)

  # キープレスイベントを処理する無名関数を作って返す。
  # イベントが発生すると、選択されているMumbleオブジェクトの配列を引数にそれを呼び出す
  def self.event_maker
    lambda{ |service|
      yield(Gtk::Mumble.get_active_mumbles) if not Gtk::Mumble.get_active_mumbles.empty? } end

  # event_makerと同じだが、ブロックは選択されているつぶやきを１つづつ取り複数回呼び出される
  def self.event_maker_each
    event_maker{ |mumbles|
      mumbles.each{ |mumble| yield mumble } } end

  shortcutkeys = [ ['つぶやきを投稿する', :mumble_post_key],
                   ['リプライ', :reply_write_key, event_maker{ |mumbles|
                      mumbles.first.gen_postbox(mumbles.first.to_message, :subreplies => mumbles) }],
                   ['公式リツイート', :retweet_key, event_maker_each(&lazy.to_message.retweet)],
                   ['ふぁぼる', :favorite_key, event_maker_each{ |m| m.to_message.favorite(!m.to_message.favorite?) }],
                   ['上のメッセージへ移動', :up_mumble_key, event_maker{ |mumbles|
                      target = mumbles.first
                      if(tl = target.get_ancestor(Gtk::TimeLine))
                        tl.inject(nil){ |before, mumble|
                          if(mumble.message[:id] == target.message[:id])
                            if before
                              before.active
                              tl.scroll_to(before) end
                            break end
                          mumble } end }],
                   ['下のメッセージへ移動', :down_mumble_key, event_maker{ |mumbles|
                      target = mumbles.first
                      if(tl = target.get_ancestor(Gtk::TimeLine))
                        active = false
                        tl.each{ |mumble|
                          if(mumble.message[:id] == target.message[:id])
                            active = true
                          elsif active
                            mumble.active
                            tl.scroll_to(mumble)
                            break end } end }]
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
