# -*- coding: utf-8 -*-

require 'gtk2'

# 設定画面のCRUD
module Plugin::ListSettings
  class Tab < ::Gtk::ListList
    attr_accessor :plugin

    SLUG = 0
    LIST = 1
    NAME = 2
    DESCRIPTION = 3
    PUBLICITY = 4

    def initialize(plugin)
      type_strict plugin => Plugin
      @plugin = plugin
      super()
      self.dialog_title = @plugin._('リスト') end

    def column_schemer
      [{:kind => :text, :type => String, :label => @plugin._('リスト名')},
       {:type => UserList},
       {:type => String, :widget => :input, :label => @plugin._('リストの名前')},
       {:type => String, :widget => :input, :label => @plugin._('リスト説明')},
       {:type => TrueClass, :widget => :boolean, :label => @plugin._('公開')},
      ].freeze
    end

    def buttons(box_klass)
      box_klass.new(false, 4).closeup(create_button).closeup(update_button).closeup(delete_button).closeup(extract_button) end

    def menu_pop(widget, event)
      _p = Plugin[:list_settings]
      contextmenu = Gtk::ContextMenu.new
      contextmenu.registmenu(_p._("新規作成"), &method(:record_create))
      contextmenu.registmenu(_p._("編集"), &method(:record_update))
      contextmenu.registmenu(_p._("削除"), &method(:record_delete))
      contextmenu.registmenu(_p._("タブを作成"), &method(:record_extract))
      contextmenu.popup(widget, widget) end

    def extract_button
      if not defined? @extract_button
        @extract_button = Gtk::Button.new(Plugin[:list_settings]._("タブを作成"))
        @extract_button.ssc(:clicked) {
          record_extract(nil, nil) } end
      @extract_button end

    def record_extract(optional, widget)
      self.selection.selected_each {|model, path, iter|
        on_extract(iter) } end

    def on_created(iter)
      iter[SLUG] = "@#{Service.primary.user}/#{iter[NAME]}"
      Service.primary.add_list(user: Service.primary.user_obj,
                               mode: iter[PUBLICITY],
                               name: iter[NAME],
                               description: iter[DESCRIPTION]){ |event, list|
        if :success == event and list
          Plugin.call(:list_created, Service.primary, UserLists.new([list]))
          if not(destroyed?)
            iter[LIST] = list
            iter[SLUG] = list[:full_name] end end } end

    def on_updated(iter)
      list = iter[LIST]
      if list
        if list[:name] != iter[NAME] || list[:description] != iter[DESCRIPTION] || list[:mode] != iter[PUBLICITY]
          Service.primary.update_list(id: list[:id],
                                      name: iter[NAME],
                                      description: iter[DESCRIPTION],
                                      mode: iter[PUBLICITY]){ |event, updated_list|
            if not(destroyed?) and event == :success and updated_list
              iter[SLUG] = updated_list[:full_name]
              iter[LIST] = updated_list
              iter[NAME] = updated_list[:name]
              iter[DESCRIPTION] = updated_list[:description]
              iter[PUBLICITY] = updated_list[:mode] end
          }.terminate end end end

    def on_deleted(iter)
      list = iter[LIST]
      if list
        Service.primary.delete_list(list_id: list[:id]){ |event, deleted_list|
          if event == :success
            Plugin.call(:list_destroy, Service.primary, UserLists.new([deleted_list]))
            model.remove(iter) if not destroyed? end
        }.terminate end end

    def on_extract(iter)
      list = iter[LIST]
      if list
        dialog = Gtk::Dialog.new(Plugin[:list_settings]._("リスト「%{list_name}」の抽出タブを作成 - %{mikutter}") % {
                                   mikutter: Environment::NAME,
                                   list_name: list[:name]
                                 }, nil, nil,
                                 [Gtk::Stock::OK, Gtk::Dialog::RESPONSE_ACCEPT],
                                 [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_REJECT])
        prompt = Gtk::Entry.new
        prompt.text = list[:name]
        dialog.vbox.
          add(Gtk::HBox.new(false, 8).
               closeup(Gtk::Label.new(Plugin[:list_settings]._("タブの名前"))).
               add(prompt).show_all)
        dialog.run{ |response|
          if Gtk::Dialog::RESPONSE_ACCEPT == response
            Plugin.call :extract_tab_create,
                        name: prompt.text,
                        icon: Skin.get_path('list.png'),
                        sources: [:"#{list.user.idname}_list_#{list[:id]}"] end
          dialog.destroy
          prompt = dialog = nil } end
    end

  end
end
