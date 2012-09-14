# -*- coding:utf-8 -*-

Module.new do

  class ShortcutKeyListView < Gtk::CRUD

    COLUMN_KEYBIND = 0
    COLUMN_COMMAND = 1
    COLUMN_SLUG = 2
    COLUMN_ID = 3

    def initialize
      super
      shortcutkeys.each{ |id, behavior|
        iter = model.append
        iter[COLUMN_ID] = id
        iter[COLUMN_KEYBIND] = behavior[:key]
        iter[COLUMN_COMMAND] = behavior[:name]
        iter[COLUMN_SLUG] = behavior[:slug]
      }
    end

    def column_schemer
      [{:kind => :text, :widget => :keyconfig, :type => String, :label => 'キーバインド'},
       {:kind => :text, :type => String, :label => '機能名'},
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
      name = Plugin.filtering(:command, Hash.new).first[iter[COLUMN_SLUG].to_sym][:name]
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

  end

  Delayer.new{
    container = ShortcutKeyListView.new
    Plugin.call(:setting_tab_regist, container, 'ショートカットキー') }

  plugin = Plugin::create(:shortcutkey)
  plugin.add_event(:keypress){ |key|
    tl, active_mumble, miracle_painter, postbox, valid_roles = Addon::Command.tampr
    type_check(tl => (tl and Gtk::TimeLine::InnerTL), active_mumble => (active_mumble and Message), miracle_painter => (miracle_painter and Gdk::MiraclePainter), postbox => (postbox and Gtk::PostBox)){
      if not(valid_roles.include?(:postbox))
        Addon::Command.call_keypress_event(key, :tl => tl, :message => active_mumble, :miracle_painter => miracle_painter, :postbox => postbox) end } }

end
