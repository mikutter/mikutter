miquire :addon, 'addon'
miquire :core, 'config'
miquire :addon, 'settings'

module Addon
  class SetView < Addon

    include SettingUtils

    @@mutex = Monitor.new

    def onboot(watch)
      container = self.main(watch)
      Plugin::Ring::fire(:plugincall, [:settings, watch, :regist_tab, container, '表示'])
    end

    def main(watch)
      box = Gtk::VBox.new(false, 8)
      box.closeup(gen_group('フォント',
                            gen_fontcolorselect(:mumble_basic_font, :mumble_basic_color, 'デフォルトのフォント'),
                            gen_fontcolorselect(:mumble_reply_font, :mumble_reply_color, 'リプライ元のフォント')))
      box.closeup(gen_group('背景色',
                            gen_colorselect(:mumble_basic_bg, 'つぶやき'),
                            gen_colorselect(:mumble_reply_bg, '自分宛'),
                            gen_colorselect(:mumble_self_bg, '自分のつぶやき')))
      box.closeup(gen_boolean(:show_cumbersome_buttons, 'つぶやきの右側にボタンを表示する'))
      box.closeup(gen_default_or_custom(:url_open_command, 'URLを開く方法', 'デフォルトブラウザを使う', '次のコマンドを使う'))
      return box
    end

  end
end

Plugin::Ring.push Addon::SetView.new,[:boot]
