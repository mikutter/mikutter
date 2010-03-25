miquire :addon, 'addon'
miquire :addon, 'settings'
miquire :core, 'config'

module Addon
  class ChangeAccount < Addon

    include SettingUtils

    @@mutex = Monitor.new

    def onboot(watch)
      watch.auth_confirm_func = lambda{|watch| self.popup(watch) }
      container, = self.main_for_tab(watch)
      Plugin::Ring::fire(:plugincall, [:settings, watch, :regist_tab, container, 'アカウント情報'])
    end

    def popup(watch)
      result = [nil]
      alert_thread = Thread.current
      dialog = Gtk::Dialog.new(Environment::NAME + " ログイン")
      container, user, pass = self.main(watch)
      dialog.window_position = Gtk::Window::POS_CENTER
      dialog.vbox.pack_start(container, true, true, 30)
      dialog.add_button(Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK)
      dialog.default_response = Gtk::Dialog::RESPONSE_OK
      dialog.signal_connect("response") do |widget, response|
        result = [user.text, pass.text]
        dialog.hide_all
        dialog.destroy
        Gtk.main_iteration_do(false)
        alert_thread.run
        Gtk::Window.toplevels.first.show
      end
      dialog.signal_connect("destroy") {
        false
      }
      container.show
      dialog.show_all
      Gtk::Window.toplevels.first.hide
      Thread.stop
      return *result
    end

    def main_for_tab(watch)
      box, user_input, pass_input = *main(watch)
      decide = Gtk::Button.new('変更')
      attention = Gtk::Label.new("変更を押すと#{Environment::NAME}を再起動します。悪しからず。")
      attention.wrap = true
      buttons = Gtk::HBox.new(false, 16)
      box.pack_start(buttons, false)
      buttons.pack_start(decide, false)
      buttons.pack_start(Gtk::EventBox.new.add(attention))
      widgets = [user_input, pass_input, decide]
      decide.signal_connect("clicked"){
        UserConfig[:twitter_idname] = user_input.text
        UserConfig[:twitter_password] = pass_input.text
        exec($0)
      }
      return box, user_input, pass_input
    end

    def main(watch)
      box = Gtk::VBox.new(false, 8)
      user, user_input = gen_input('ユーザ名', true, (watch.user or ""))
      pass, pass_input = gen_input('パスワード', false)
      box.pack_start(user, false)
      box.pack_start(pass, false)
      return box, user_input, pass_input
    end

    def gen_input(label, visibility=true, default="")
      container = Gtk::HBox.new(false, 0)
      input = Gtk::Entry.new
      input.text = default
      input.visibility = visibility
      container.pack_start(Gtk::Label.new(label), false, true, 0)
      container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(input), true, true, 0)
      return container, input
    end

  end
end

Plugin::Ring.push Addon::ChangeAccount.new,[:boot]
