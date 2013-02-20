# -*- coding: utf-8 -*-

module Plugin::Shortcutkey
  class ShortcutKeyListView < ::Gtk::CRUD

    COLUMN_KEYBIND = 0
    COLUMN_COMMAND_ICON = 1
    COLUMN_COMMAND = 2
    COLUMN_SLUG = 3
    COLUMN_ID = 4

    def initialize
      super
      commands = Plugin.filtering(:command, Hash.new).first
      shortcutkeys.each{ |id, behavior|
        slug = behavior[:slug]
        iter = model.append
        iter[COLUMN_ID] = id
        iter[COLUMN_KEYBIND] = behavior[:key]
        iter[COLUMN_COMMAND] = behavior[:name]
        iter[COLUMN_SLUG] = slug
        if commands[slug]
          icon = commands[slug][:icon]
          icon = icon.call(nil) if icon.is_a? Proc
          if icon
            iter[COLUMN_COMMAND_ICON] = Gdk::WebImageLoader.pixbuf(icon, 16, 16){ |pixbuf|
              if not destroyed?
                iter[COLUMN_COMMAND_ICON] = pixbuf end } end end } end

    def column_schemer
      [{:kind => :text, :widget => :keyconfig, :type => String, :label => 'キーバインド'},
       [{:kind => :pixbuf, :type => Gdk::Pixbuf, :label => '機能名'},
        {:kind => :text, :type => String, :expand => true}],
       {:kind => :text, :widget => :chooseone, :args => [Hash[Plugin.filtering(:command, Hash.new).first.values.map{ |x|
                                                            [x[:slug], x[:name]]
                                                          }].freeze],
         :type => Symbol},
       {:type => Integer},
      ].freeze
    end

    def shortcutkeys
      (UserConfig[:shortcutkey_keybinds] || Hash.new).dup end

    def new_serial
      @new_serial ||= (shortcutkeys.keys.max || 0)
      @new_serial += 1 end

    def on_created(iter)
      bind = shortcutkeys
      p [iter[COLUMN_SLUG], iter[COLUMN_KEYBIND]]
      name = Plugin.filtering(:command, Hash.new).first[iter[COLUMN_SLUG].to_sym][:name]
      name = name.call(nil) if name.is_a? Proc
      iter[COLUMN_ID] = new_serial
      bind[iter[COLUMN_ID]] = {
        :key => iter[COLUMN_KEYBIND].to_s,
        :name => name,
        :slug => iter[COLUMN_SLUG].to_sym }
      iter[COLUMN_COMMAND] = name
      UserConfig[:shortcutkey_keybinds] = bind
    end

    def on_updated(iter)
      bind = shortcutkeys
      name = Plugin.filtering(:command, Hash.new).first[iter[COLUMN_SLUG].to_sym][:name]
      name = name.call(nil) if name.is_a? Proc
      bind[iter[COLUMN_ID].to_i] = {
        :key => iter[COLUMN_KEYBIND].to_s,
        :name => name,
        :slug => iter[COLUMN_SLUG].to_sym }
      iter[COLUMN_COMMAND] = name
      UserConfig[:shortcutkey_keybinds] = bind
    end

    def on_deleted(iter)
      bind = shortcutkeys
      bind.delete(iter[COLUMN_ID].to_i)
      UserConfig[:shortcutkey_keybinds] = bind
    end

    def popup_input_window(defaults = [])
      values = defaults.dup
      result = nil
      defaults.freeze
      window = KeyConfigWindow.new("設定 - " + Environment::NAME)
      window.transient_for = toplevel
      window.modal = true
      window.destroy_with_parent = true
      btn_ok = ::Gtk::Button.new("OK")
      btn_cancel = ::Gtk::Button.new("キャンセル")
      window.
        add(::Gtk::VBox.new(false, 16).
            add(::Gtk::HBox.new(false, 16).
                add(key_box(values)).
                add(command_box(values))).
            closeup(::Gtk::HButtonBox.new.set_layout_style(::Gtk::ButtonBox::END).
                    add(btn_cancel).
                    add(btn_ok)))
      window.show_all

      window.ssc(:destroy){ ::Gtk::main_quit }
      btn_cancel.ssc(:clicked){ window.destroy }
      btn_ok.ssc(:clicked){
        error = catch(:validate) {
          throw :validate, "キーバインドを選択してください" unless values[COLUMN_KEYBIND]
          throw :validate, "コマンドを選択してください" unless values[COLUMN_SLUG]
          result = values
          window.destroy }
        if error
          dialog = ::Gtk::MessageDialog.new(window,
                                            ::Gtk::Dialog::DESTROY_WITH_PARENT,
                                            ::Gtk::MessageDialog::WARNING,
                                            ::Gtk::MessageDialog::BUTTONS_OK,
                                            error)
          dialog.run
          dialog.destroy end }
      ::Gtk::main
      result end

    def key_box(results)
      container = ::Gtk::VBox.new(false, 16)
      button = ::Gtk::KeyConfig.new('キーバインド', results[COLUMN_KEYBIND])
      button.change_hook = lambda { |new| results[COLUMN_KEYBIND] = new }
      container.
        closeup(::Gtk::Label.new('キーバインド')).
        closeup(button) end

    def command_box(results)
      treeview = CommandList.new(results)
      scrollbar = ::Gtk::VScrollbar.new(treeview.vadjustment)
      return ::Gtk::HBox.new(false, 0).
                add(treeview).
                closeup(scrollbar)
      ::Gtk::VBox.new(false, 16).
        closeup(::Gtk::Label.new('コマンド')).
        closeup(::Gtk::HBox.new(false, 0).
                add(treeview).
                closeup(scrollbar))
    end

    class KeyConfigWindow < ::Gtk::Window
      def initialize(*args)
        super
        set_size_request(640, 480)
        window_position = ::Gtk::Window::POS_CENTER
      end
    end

    class CommandList < ::Gtk::TreeView
      include Gtk::TreeViewPrettyScroll
      COL_ICON = 0
      COL_NAME = 1
      COL_SLUG = 2
      def initialize(results)
        super(::Gtk::TreeStore.new(Gdk::Pixbuf, String, Symbol))
        append_column ::Gtk::TreeViewColumn.new("", ::Gtk::CellRendererPixbuf.new, pixbuf: COL_ICON)
        append_column ::Gtk::TreeViewColumn.new("コマンド名", ::Gtk::CellRendererText.new, text: COL_NAME)
        append_column ::Gtk::TreeViewColumn.new("スラッグ", ::Gtk::CellRendererText.new, text: COL_SLUG)
        parents = Hash.new{ |h, k| # role => TreeIter
          h[k] = iter = model.append(nil)
          iter[COL_NAME] = k.to_s
          iter
        }
        commands = Plugin.filtering(:command, Hash.new).first.map{ |slug, command|
          iter = model.append(parents[command[:role]])
          icon = command[:icon]
          icon = icon.call(nil) if icon.is_a? Proc
          if icon
            iter[COL_ICON] = Gdk::WebImageLoader.pixbuf(icon, 16, 16){ |pixbuf|
              if not destroyed?
                iter[COL_ICON] = pixbuf end } end
          name = command[:name]
          name = name.call(nil) if name.is_a? Proc
          iter[COL_NAME] = name
          iter[COL_SLUG] = slug
          if results[Plugin::Shortcutkey::ShortcutKeyListView::COLUMN_SLUG].to_s == slug.to_s
            expand_row(iter.parent.path, true)
            selection.select_iter(iter)
          end
        }
        signal_connect("cursor-changed"){
          iter = selection.selected
          if iter
            results[Plugin::Shortcutkey::ShortcutKeyListView::COLUMN_COMMAND] = iter[COL_NAME]
            results[Plugin::Shortcutkey::ShortcutKeyListView::COLUMN_SLUG] = iter[COL_SLUG]
          end
          false }
        selected = selection.selected
        if selected
          scroll_to_cell(selected.path, nil, false, 0.5, 0) end
      end
    end

  end
end
