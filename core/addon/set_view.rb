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
      box.pack_start(gen_boolean(:show_cumbersome_buttons, 'つぶやきの右側にボタンを表示する'), false)
      return box
    end

  end
end

Plugin::Ring.push Addon::SetView.new,[:boot]
