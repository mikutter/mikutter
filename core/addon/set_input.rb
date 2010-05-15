miquire :addon, 'addon'
miquire :core, 'config'
miquire :addon, 'settings'

module Addon
  class SetInput < Addon

    include SettingUtils

    def onboot(watch)
      container = self.main(watch)
      Plugin::Ring::fire(:plugincall, [:settings, watch, :regist_tab, container, '入力'])
    end

    def main(watch)
      box = Gtk::VBox.new(false, 8)
      box.pack_start(gen_keyconfig('つぶやきを投稿するキー', :mumble_post_key), false)
      box.closeup(gen_boolean(:shrinkurl_always, '常にURLを短縮する'))
      return box
    end

  end
end

Plugin::Ring.push Addon::SetInput.new,[:boot]
