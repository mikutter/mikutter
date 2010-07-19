# -*- coding: utf-8 -*-

miquire :addon, 'addon'
miquire :core, 'userconfig'
miquire :mui, 'skin'
miquire :mui, 'mtk'

Module.new do
  plugin = Plugin::create(:settings)
  book = Gtk::Notebook.new.set_tab_pos(Gtk::POS_TOP)

  plugin.add_event(:boot){ |service|
    Plugin.call(:mui_tab_regist, book, 'Settings', MUI::Skin.get("settings.png")) }

  plugin.add_event(:setting_tab_regist){ |box, label|
    box = box.call if box.respond_to?(:call)
    container = Gtk::ScrolledWindow.new()
    container.set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_AUTOMATIC)
    container.add_with_viewport(box)
    book.append_page(container, Gtk::Label.new(label))
    book.show_all }
end

Module.new do
  plugin = Plugin::create(:basic_settings)
  box = Gtk::VBox.new(false, 0)
  retrieve_interval = Mtk.group('各情報を取りに行く間隔。単位は分',
                                Mtk.adjustment('タイムラインとリプライ',
                                               :retrieve_interval_friendtl, 1, 60*24).
                                tooltip('あなたがフォローしている人からのリプライとつぶやきの取得間隔'),
                                Mtk.adjustment('フォローしていない人からのリプライ',
                                               :retrieve_interval_mention, 1, 60*24).
                                tooltip("あなたに送られてきたリプライを取得する間隔。\n上との違いは、あなたがフォローしていない人からのリプライも取得出来ることです"),
                                Mtk.adjustment('保存した検索',
                                               :retrieve_interval_search, 1, 60*24).
                                tooltip('保存した検索を確認しに行く間隔'),
                                Mtk.adjustment('フォロー',
                                               :retrieve_interval_followings, 1, 60*24).
                                tooltip('フォロー一覧を確認しに行く間隔。mikutterを使わずにフォローした場合、この時に同期される'),
                                Mtk.adjustment('フォロワー',
                                               :retrieve_interval_followers, 1, 60*24).
                                tooltip('フォロワー一覧を確認しに行く間隔'))
  retrieve_count = Gtk::Frame.new('一度に取得するつぶやきの件数(1-3200)').set_border_width(8)
  rcbox = Gtk::VBox.new(false, 0).set_border_width(4)
  retrieve_count.add(rcbox)
  rcbox.pack_start(Mtk.adjustment('タイムラインとリプライ', :retrieve_count_friendtl, 1, 3200), false)
  rcbox.pack_start(Mtk.adjustment('フォローしていない人からのリプライ', :retrieve_count_mention, 1, 3200), false)
  rcbox.pack_start(Mtk.adjustment('フォロー', :retrieve_count_followings, 1, 100000), false)
  rcbox.pack_start(Mtk.adjustment('フォロワー', :retrieve_count_followers, 1, 100000), false)
  box.pack_start(retrieve_interval, false)
  box.pack_start(retrieve_count, false)
  box.pack_start(Mtk.boolean(:retrieve_force_mumbleparent, 'リプライ元をサーバに問い合わせて取得する'), false)
  box.pack_start(Mtk.boolean(:anti_retrieve_fail, 'つぶやきの取得漏れを防止する（遅延対策）'), false)
  box.pack_start(Gtk::Label.new('遅延に強くなりますが、ちょっと遅くなります。'), false)

  plugin.add_event(:boot){ |service|
    Plugin.call(:setting_tab_regist, box, '基本設定') }
end
