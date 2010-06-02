# -*- coding: utf-8 -*-

miquire :addon, 'addon'
miquire :core, 'userconfig'
miquire :mui, 'skin'

module Addon::SettingUtils; end

class Addon::Settings < Addon::Addon

  include Addon::SettingUtils

  def onboot(watch)
    Gtk::Lock.synchronize{
      self.regist_tab(watch, self.book, 'Se', MUI::Skin.get("settings.png"))
      rewind_interval
    }
  end

  def onplugincall(watch, command, *args)
    case command
    when :regist_tab
      self.regist_config_tab(*args)
    end
  end

  def book()
    if not(@book) then
      @book = Gtk::Lock.synchronize{
        Gtk::Notebook.new.set_tab_pos(Gtk::POS_TOP)
      }
    end
    return @book
  end

  def regist_config_tab(container, label)
    Gtk::Lock.synchronize{
      self.book.append_page(container, Gtk::Label.new(label))
      self.book.show_all
    }
  end

  def rewind_interval
    container = Gtk::ScrolledWindow.new()
    container.set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_AUTOMATIC)
    box = Gtk::VBox.new(false, 0)
    retrieve_interval = gen_group('各情報を取りに行く間隔。単位は分',
                                  help(gen_adjustment('タイムラインとリプライ',
                                                      :retrieve_interval_friendtl, 1, 60*24),
                                       'あなたがフォローしている人からのリプライとつぶやきの取得間隔'),
                                  help(gen_adjustment('フォローしていない人からのリプライ',
                                                      :retrieve_interval_mention, 1, 60*24),
                                       "あなたに送られてきたリプライを取得する間隔。\n上との違いは、あなたがフォローしていない人からのリプライも取得出来ることです"),
                                  help(gen_adjustment('保存した検索',
                                                      :retrieve_interval_search, 1, 60*24),
                                       '保存した検索を確認しに行く間隔'),
                                  help(gen_adjustment('フォロワー',
                                                      :retrieve_interval_followed, 1, 60*24),
                                       'フォロワー一覧を確認しに行く間隔'))
    retrieve_count = Gtk::Frame.new('一度に取得するつぶやきの件数(1-3200)').set_border_width(8)
    rcbox = Gtk::VBox.new(false, 0).set_border_width(4)
    retrieve_count.add(rcbox)
    rcbox.pack_start(gen_adjustment('タイムラインとリプライ', :retrieve_count_friendtl, 1, 3200), false)
    rcbox.pack_start(gen_adjustment('フォローしていない人からのリプライ', :retrieve_count_mention, 1, 3200), false)
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

module Addon::SettingUtils

  def help(widget, text)
    Gtk::Tooltips.new.set_tip(widget, text, nil)
    widget
  end

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

  def gen_group(title, *children)
    group = Gtk::Frame.new(title).set_border_width(8)
    box = Gtk::VBox.new(false, 0).set_border_width(4)
    group.add(box)
    children.each{ |w|
      box.pack_start(w, false)
    }
    group
  end

  def gen_fileselect(key, label, current=Dir.pwd)
    container, input = gen_input(label, key)
    button = Gtk::Button.new('参照')
    container.pack_start(button, false)
    button.signal_connect('clicked'){ |widget|
      dialog = Gtk::FileChooserDialog.new("Open File",
                                          widget.get_ancestor(Gtk::Window),
                                          Gtk::FileChooser::ACTION_OPEN,
                                          nil,
                                          [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                                          [Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT])
      dialog.current_folder = File.expand_path(current)
      if dialog.run == Gtk::Dialog::RESPONSE_ACCEPT
        UserConfig[key] = dialog.filename
        input.text = dialog.filename
      end
      dialog.destroy
    }
    container
  end

  def colorselect(key, label)
    color = UserConfig[key]
    button = Gtk::ColorButton.new((color and Gdk::Color.new(*color)))
    button.title = label
    button.signal_connect('color-set'){ |w|
      UserConfig[key] = w.color.to_a }
    button end

  def fontselect(key, label)
    button = Gtk::FontButton.new(UserConfig[key])
    button.title = label
    button.signal_connect('font-set'){ |w|
      UserConfig[key] = w.font_name }
    button end

  def gen_fontselect(key, label)
    Gtk::HBox.new(false, 0).add(Gtk::Label.new(label).left).closeup(fontselect(key, label))
  end

  def gen_colorselect(key, label)
    Gtk::HBox.new(false, 0).add(Gtk::Label.new(label).left).closeup(colorselect(key, label))
  end

  def gen_fontcolorselect(font, color, label)
    gen_fontselect(font, label).closeup(colorselect(color, label))
  end

  def gen_accountdialog_button(label, kuser, lvuser,  kpasswd, lvpasswd, &validator)
    btn = Gtk::Button.new(label)
    btn.signal_connect('clicked'){
      account_dialog(label, kuser, lvuser,  kpasswd, lvpasswd, &validator) }
    btn
  end

  def account_dialog_inner(kuser, lvuser,  kpasswd, lvpasswd, cancel=true)
    def input(label, visibility=true, default="")
      container = Gtk::HBox.new(false, 0)
      input = Gtk::Entry.new
      input.text = default
      input.visibility = visibility
      container.pack_start(Gtk::Label.new(label), false, true, 0)
      container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(input), true, true, 0)
      return container, input
    end
    box = Gtk::VBox.new(false, 8)
    user, user_input = input(lvuser, true, (UserConfig[kuser] or ""))
    pass, pass_input = input(lvpasswd, false)
    return box.closeup(user).closeup(pass), user_input, pass_input
  end

  def account_dialog(label, kuser, lvuser,  kpasswd, lvpasswd, cancel=true, &validator)
    alert_thread = if(Thread.main != Thread.current) then Thread.current end
    dialog = Gtk::Dialog.new(label)
    dialog.window_position = Gtk::Window::POS_CENTER
    container,iuser,ipass = account_dialog_inner(kuser, lvuser,  kpasswd, lvpasswd)
    dialog.vbox.pack_start(container, true, true, 30)
    dialog.add_button(Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK)
    dialog.add_button(Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL) if cancel
    dialog.default_response = Gtk::Dialog::RESPONSE_OK
    quit = lambda{
      dialog.hide_all.destroy
      Gtk.main_iteration_do(false)
      Gtk::Window.toplevels.first.show
      if alert_thread
        alert_thread.run
      else
        Gtk.main_quit
      end }
    dialog.signal_connect("response"){ |widget, response|
      if response == Gtk::Dialog::RESPONSE_OK
        if validator.call(iuser.text, ipass.text)
          UserConfig[kuser] = iuser.text
          UserConfig[kpasswd] = ipass.text
          quit.call
        else
          alert("#{lvuser}か#{lvpasswd}が違います")
        end
      elsif (cancel and response == Gtk::Dialog::RESPONSE_CANCEL) or
          response == Gtk::Dialog::RESPONSE_DELETE_EVENT
        quit.call
      end }
    dialog.signal_connect("destroy") {
      false
    }
    container.show
    dialog.show_all
    Gtk::Window.toplevels.first.hide
    if(alert_thread)
      Thread.stop
    else
      Gtk::main
    end
  end

  def alert(message)
    dialog = Gtk::MessageDialog.new(nil,
                                    Gtk::Dialog::DESTROY_WITH_PARENT,
                                    Gtk::MessageDialog::QUESTION,
                                    Gtk::MessageDialog::BUTTONS_CLOSE,
                                    message)
    dialog.run
    dialog.destroy
  end

end

Plugin::Ring.push Addon::Settings.new,[:boot]
