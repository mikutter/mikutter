miquire :addon, 'addon'
miquire :core, 'config'
miquire :addon, 'settings'

Module.new do

  container = Gtk::VBox.new(false, 8).
    closeup(Mtk.group('フォント',
                      Mtk.fontcolorselect(:mumble_basic_font, :mumble_basic_color, 'デフォルトのフォント'),
                      Mtk.fontcolorselect(:mumble_reply_font, :mumble_reply_color, 'リプライ元のフォント'))).
    closeup(Mtk.group('背景色',
                      Mtk.colorselect(:mumble_basic_bg, 'つぶやき'),
                      Mtk.colorselect(:mumble_reply_bg, '自分宛'),
                      Mtk.colorselect(:mumble_self_bg, '自分のつぶやき'))).
    closeup(Mtk.boolean(:show_cumbersome_buttons, 'つぶやきの右側にボタンを表示する')).
    closeup(Mtk.boolean(:show_replied_icon, 'リプライを返したつぶやきにはアイコンを表示')).
    closeup(Mtk.boolean(:favorited_by_anyone_act_as_reply, 'ふぁぼられをリプライの受信として処理する')).
    closeup(Mtk.group('短縮URL', Mtk.boolean(:shrinkurl_expand, '短縮URLを展開して表示'))).
    closeup(Mtk.chooseone(:tab_position, 'タブの位置', 0 => '上', 1 => '下', 2 => '左', 3 => '右')).
    closeup(Mtk.default_or_custom(:url_open_command, 'URLを開く方法', 'デフォルトブラウザを使う', '次のコマンドを使う'))

  plugin = Plugin::create(:set_view)

  plugin.add_event(:boot){ |service|
    Plugin.call(:setting_tab_regist, container, '表示') }

end

#Plugin::Ring.push Addon::SetView.new,[:boot]
