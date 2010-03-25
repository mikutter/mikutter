
miquire :addon, 'addon'
miquire :core, 'userconfig'

module Addon
  module SettingUtils; end

  class Settings < Addon

    include SettingUtils

    @@mutex = Monitor.new

    def onboot(watch)
      self.regist_tab(self.book, 'Se')
      rewind_interval
    end

    def onplugincall(watch, command, *args)
      case command
      when :regist_tab
        self.regist_config_tab(*args)
      end
    end

    def book()
      if not(@book) then
        @book = Gtk::Notebook.new
        @book.set_tab_pos(Gtk::POS_TOP)
      end
      return @book
    end

    def regist_config_tab(container, label)
      @@mutex.synchronize{
        self.book.append_page(container, Gtk::Label.new(label))
        self.book.show_all
      }
    end

    def rewind_interval
      container = Gtk::ScrolledWindow.new()
      container.set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_AUTOMATIC)
      box = Gtk::VBox.new(false, 0)
      retrieve_interval = Gtk::Frame.new('各情報を取りに行く間隔。単位は分').set_border_width(8)
      ribox = Gtk::VBox.new(false, 0).set_border_width(4)
      retrieve_interval.add(ribox)
      ribox.pack_start(gen_adjustment('フレンドタイムライン', :retrieve_interval_friendtl, 1, 60*24), false)
      ribox.pack_start(gen_adjustment('リプライ', :retrieve_interval_mention, 1, 60*24), false)
      ribox.pack_start(gen_adjustment('フォロワー', :retrieve_interval_followed, 1, 60*24), false)
      retrieve_count = Gtk::Frame.new('一度に取得するつぶやきの件数(1-3200)').set_border_width(8)
      rcbox = Gtk::VBox.new(false, 0).set_border_width(4)
      retrieve_count.add(rcbox)
      rcbox.pack_start(gen_adjustment('フレンドタイムライン', :retrieve_count_friendtl, 1, 3200), false)
      rcbox.pack_start(gen_adjustment('リプライ', :retrieve_count_mention, 1, 3200), false)
      rcbox.pack_start(gen_adjustment('フォロワー', :retrieve_interval_followed, 1, 3200), false)
      box.pack_start(retrieve_interval, false)
      box.pack_start(retrieve_count, false)
      box.pack_start(gen_boolean(:retrieve_force_mumbleparent, 'リプライ元をサーバに問い合わせて取得する'), false)
      box.pack_start(gen_boolean(:anti_retrieve_fail, 'つぶやきの取得漏れを防止する（遅延対策）'), false)
      box.pack_start(Gtk::Label.new('遅延に強くなりますが、ちょっと遅くなります。'), false)
      container.add_with_viewport(box)
      regist_config_tab(container, '基本設定')
    end

  end

  module SettingUtils

    def gen_adjustment(name, config, min, max)
      container = Gtk::HBox.new(false, 0)
      container.pack_start(Gtk::Label.new(name), false, true, 0)
      adj = Gtk::Adjustment.new((UserConfig[config] or min), min*1.0, max*1.0, 1.0, 5.0, 0.0)
      spinner = Gtk::SpinButton.new(adj, 0, 0)
      spinner.wrap = true
      adj.signal_connect('value-changed'){ |widget, e|
        UserConfig[config] = widget.value.to_i
        false
      }
      container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(spinner), true, true, 0)
    end

    def gen_chooseone(label, config_key, values)
      container = Gtk::HBox.new(false, 0)
      input = Gtk::ComboBox.new(true)
      values.keys.sort.each{ |key|
        input.append_text(values[key])
      }
      input.signal_connect('changed'){ |widget|
        Gtk::Lock.synchronize do
          UserConfig[config_key] = values.keys.sort[widget.active]
        end
      }
      input.active = values.keys.sort.index((UserConfig[config_key] or 0))
      container.pack_start(Gtk::Label.new(label), false, true, 0)
      container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(input), true, true, 0)
      return container
    end

    def gen_boolean(config_key, label)
      input = Gtk::CheckButton.new(label)
      input.signal_connect('toggled'){ |widget|
        Gtk::Lock.synchronize do
          UserConfig[config_key] = widget.active?
        end
      }
      input.active = UserConfig[config_key]
      return input
    end

    def gen_input(label, key, visibility=true)
      container = Gtk::HBox.new(false, 0)
      input = Gtk::Entry.new
      input.text = UserConfig[key].to_s
      input.visibility = visibility
      container.pack_start(Gtk::Label.new(label), false, true, 0)
      container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(input), true, true, 0)
      input.signal_connect('changed'){ |widget|
        UserConfig[key] = widget.text
      }
      return container, input
    end

    def gen_keyconfig(title, key)
      keyconfig = Gtk::KeyConfig.new(title, UserConfig[key])
      container = Gtk::HBox.new(false, 0)
      container.pack_start(Gtk::Label.new(title), false, true, 0)
      container.pack_start(keyconfig, true, true, 0)
      keyconfig.change_hook = lambda{ |keycode|
        UserConfig[key] = keycode
      }
      return container
    end

  end

end

Plugin::Ring.push Addon::Settings.new,[:boot]
