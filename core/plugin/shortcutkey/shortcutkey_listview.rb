# -*- coding: utf-8 -*-

module Plugin::Shortcutkey
  class ShortcutKeyListView < ::Gtk::CRUD

    COLUMN_KEYBIND = 0
    COLUMN_COMMAND_ICON = 1
    COLUMN_COMMAND = 2
    COLUMN_SLUG = 3
    COLUMN_WORLD_FACE = 4
    COLUMN_WORLD = 5
    COLUMN_ID = 6

    attr_accessor :filter_entry

    def initialize(plugin)
      type_strict plugin => Plugin
      @plugin = plugin
      super()
      set_model(Gtk::TreeModelFilter.new(model))
      model.set_visible_func do |model, iter|
        if defined?(@filter_entry) and @filter_entry
          query = @filter_entry.text
          Enumerator.new {|y|
            y << iter[COLUMN_KEYBIND] << iter[COLUMN_COMMAND] << iter[COLUMN_SLUG]
            iter[COLUMN_WORLD].yield_self do |w|
              y << w.uri << w.title if w.is_a? Diva::Model
            end
          }.any? {|x| x.to_s.include?(query) }
        else
          true
        end
      end
      commands = Plugin.filtering(:command, Hash.new).first
      worlds = world_selections(key: ->(k) { k.uri.to_s })
      shortcutkeys.each do |id, behavior|
        slug = behavior[:slug]
        iter = model.model.append
        iter[COLUMN_ID] = id
        iter[COLUMN_KEYBIND] = behavior[:key]
        iter[COLUMN_COMMAND] = behavior[:name]
        iter[COLUMN_SLUG] = slug
        iter[COLUMN_WORLD] = worlds[behavior[:world]]
        update_iter(iter, force: false)
        commands.dig(slug, :icon)&.yield_self {|icon|
          icon.is_a?(Proc) ? icon.call(nil) : icon
        }&.yield_self {|icon|
          Diva::Model(:photo)[icon]
        }&.yield_self do |icon|
          iter[COLUMN_COMMAND_ICON] = icon.load_pixbuf(width: Gdk.scale(16), height: Gdk.scale(16)) do |pixbuf|
            iter[COLUMN_COMMAND_ICON] = pixbuf if not destroyed?
          end
        end
      end
    end

    def column_schemer
      [{ kind:   :text,
         widget: :keyconfig,
         type:   String,
         label:  @plugin._('キーバインド')
       },
       [{ kind:  :pixbuf,
          type:  GdkPixbuf::Pixbuf,
          label: @plugin._('機能名')
        },
        { kind:   :text,
          type:   String,
          expand: true
        }
       ],
       { kind:   :text,
         widget: :chooseone,
         args:   command_dict_slug_to_name,
         type:   Symbol
       },
       { kind:     :text,
         label:    @plugin._('アカウント'),
         type:     String
       },
       { widget:   :chooseone,
         args:     worlds_dict_slug_to_name,
         type:     Object        # World Model or :current
       },
       { type: Integer
       },
      ].freeze
    end

    def command_dict_slug_to_name
      Hash[
        Plugin.filtering(:command, Hash.new)
          .first
          .values
          .map {|x| [x[:slug], x[:name]] }
      ]
    end

    def worlds_dict_slug_to_name
      Hash[
        Enumerator.new {|y| Plugin.filtering(:worlds, y) }
          .map {|x| [x.uri, x.title] }
      ]
    end

    def shortcutkeys
      UserConfig[:shortcutkey_keybinds] || {}.freeze
    end

    def new_serial
      @new_serial ||= (shortcutkeys.keys.max || 0)
      @new_serial += 1 end

    def on_created(iter)
      iter[COLUMN_ID] = new_serial
      merge_key_bind(iter)
    end

    def on_updated(iter)
      merge_key_bind(iter)
    end

    def on_deleted(iter)
      bind = shortcutkeys.dup
      bind.delete(iter[COLUMN_ID].to_i)
      UserConfig[:shortcutkey_keybinds] = bind
    end

    def popup_input_window(defaults = [])
      values = defaults.dup
      result = nil
      defaults.freeze
      window = KeyConfigWindow.new(@plugin._("設定 - %{software_name}") % {software_name: Environment::NAME})
      window.transient_for = toplevel
      window.modal = true
      window.destroy_with_parent = true
      btn_ok = ::Gtk::Button.new(@plugin._("OK"))
      btn_cancel = ::Gtk::Button.new(@plugin._("キャンセル"))
      window.
        add(::Gtk::VBox.new(false, 16).
              add(::Gtk::VBox.new(false, 16).
                    closeup(key_box(values)).
                    closeup(world_box(values)).
                    add(command_box(values))).
              closeup(::Gtk::HButtonBox.new.set_layout_style(::Gtk::ButtonBox::END).
                        add(btn_cancel).
                        add(btn_ok)))
      window.show_all

      window.ssc(:destroy) { ::Gtk::main_quit }
      btn_cancel.ssc(:clicked) { window.destroy }
      btn_ok.ssc(:clicked) {
        error = catch(:validate) {
          throw :validate, @plugin._("キーバインドを選択してください") unless (values[COLUMN_KEYBIND] && values[COLUMN_KEYBIND] != "")
          throw :validate, @plugin._("コマンドを選択してください") unless values[COLUMN_SLUG]
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

    private

    def update_iter(iter, force: false)
      if force
        iter[COLUMN_COMMAND] = name_of(iter)
      else
        iter[COLUMN_COMMAND] ||= name_of(iter)
      end
      iter[COLUMN_WORLD_FACE] =
        if iter[COLUMN_WORLD]
          iter[COLUMN_WORLD].title
        else
          @plugin._('カレントアカウント')
        end
    end

    def merge_key_bind(iter)
      update_iter(iter, force: true)
      UserConfig[:shortcutkey_keybinds] = shortcutkeys.merge(
        iter[COLUMN_ID].to_i => bind_of(iter)
      )
    end

    def bind_of(iter)
      {
        key: -iter[COLUMN_KEYBIND].to_s,
        name: -iter[COLUMN_COMMAND].to_s,
        slug: iter[COLUMN_SLUG].to_sym,
        world:
          if iter[COLUMN_WORLD]
            iter[COLUMN_WORLD].uri&.to_s
          end
      }
    end

    def name_of(iter)
      name = Plugin.filtering(:command, Hash.new).first[iter[COLUMN_SLUG].to_sym][:name]
      name = name.call(nil) if name.is_a? Proc
      name
    end

    def key_box(results)
      container = ::Gtk::HBox.new(false, 0)
      button = ::Gtk::KeyConfig.new(@plugin._('キーバインド'), results[COLUMN_KEYBIND])
      button.width_request = HYDE
      button.change_hook = lambda { |new| results[COLUMN_KEYBIND] = new }
      container.pack_start(::Gtk::Label.new(@plugin._('キーバインド')), false, true, 0)
      container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(button), true, true, 0) end

    def world_box(results)
      faces = world_selections(value: :title)
      Mtk.chooseone(
        ->(new) {
          case new
          when :current
            results[COLUMN_WORLD_FACE] = @plugin._('カレントアカウント')
            results[COLUMN_WORLD] = nil
          when nil
            results[COLUMN_WORLD]
          else
            results[COLUMN_WORLD_FACE] = faces[new]
            results[COLUMN_WORLD] = new
          end
        },
        @plugin._('アカウント'),
        faces
      )
    end

    def command_box(results)
      treeview = CommandList.new(@plugin, results)
      scrollbar = ::Gtk::VScrollbar.new(treeview.vadjustment)
      filter_entry = treeview.filter_entry = Gtk::Entry.new
      filter_entry.primary_icon_pixbuf = Skin[:search].pixbuf(width: 24, height: 24)
      filter_entry.ssc(:changed) {
        treeview.model.refilter
        false }
      return ::Gtk::VBox.new(false, 0)
        .closeup(filter_entry)
        .add(::Gtk::HBox.new(false, 0).
               add(treeview).
               closeup(scrollbar))
    end

    def world_selections(key: :itself, value: :itself)
      Hash[[[:current, @plugin._('カレントアカウント')],
            *Enumerator.new {|y| Plugin.filtering(:worlds, y) }.map { |w|
              [key.to_proc.call(w), value.to_proc.call(w)]
            }]]
    end

    class KeyConfigWindow < ::Gtk::Window
      def initialize(*args)
        super
        set_size_request(640, 480)
        self.window_position = ::Gtk::Window::POS_CENTER
      end
    end

    class CommandList < ::Gtk::TreeView
      include Gtk::TreeViewPrettyScroll

      COL_ICON = 0
      COL_NAME = 1
      COL_SLUG = 2

      attr_accessor :filter_entry

      def initialize(plugin, results)
        type_strict plugin => Plugin
        @plugin = plugin
        super(::Gtk::TreeModelFilter.new(::Gtk::TreeStore.new(::GdkPixbuf::Pixbuf, String, Symbol)))
        model.set_visible_func { |model, iter|
          if defined?(@filter_entry) and @filter_entry
            iter_match(iter, @filter_entry.text)
          else
            true
          end
        }
        append_column ::Gtk::TreeViewColumn.new("", ::Gtk::CellRendererPixbuf.new, pixbuf: COL_ICON)
        append_column ::Gtk::TreeViewColumn.new(@plugin._("コマンド名"), ::Gtk::CellRendererText.new, text: COL_NAME)
        append_column ::Gtk::TreeViewColumn.new(@plugin._("スラッグ"), ::Gtk::CellRendererText.new, text: COL_SLUG)
        parents = Hash.new { |h, k| # role => TreeIter
          h[k] = iter = model.model.append(nil)
          iter[COL_NAME] = k.to_s
          iter
        }
        Plugin.filtering(:command, Hash.new).first.map { |slug, command|
          iter = model.model.append(parents[command[:role]])
          icon = icon_model(command[:icon])
          if icon
            iter[COL_ICON] = icon.load_pixbuf(width: Gdk.scale(16), height: Gdk.scale(16)) do |pixbuf|
              iter[COL_ICON] = pixbuf if not destroyed?
            end
          end
          name = command[:name]
          name = name.call(nil) if name.is_a? Proc
          iter[COL_NAME] = name
          iter[COL_SLUG] = slug
          if results[Plugin::Shortcutkey::ShortcutKeyListView::COLUMN_SLUG].to_s == slug.to_s
            expand_row(iter.parent.path, true)
            selection.select_iter(iter)
          end
        }
        ssc(:cursor_changed) do
          iter = selection.selected
          if iter
            results[Plugin::Shortcutkey::ShortcutKeyListView::COLUMN_COMMAND] = iter[COL_NAME]
            results[Plugin::Shortcutkey::ShortcutKeyListView::COLUMN_SLUG] = iter[COL_SLUG]
          end
          false
        end
        selected = selection.selected
        if selected
          scroll_to_cell(selected.path, nil, false, 0.5, 0)
        end
      end

      private

      def icon_model(icon)
        case icon
        when Proc
          icon_model(icon.call(nil))
        when Diva::Model
          icon
        when String, URI, Addressable::URI, Diva::URI
          Enumerator.new {|y| Plugin.filtering(:photo_filter, icon, y) }.first
        end
      end

      def iter_match(iter, text)
        if [COL_NAME, COL_SLUG].any? { |column| iter[column].to_s.include?(text) }
          true
        elsif iter.has_child?
          iter.n_children.times.any? { |i| iter_match(iter.nth_child(i), text) }
        end
      end
    end
  end
end
