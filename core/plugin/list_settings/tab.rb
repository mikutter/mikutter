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
      self.dialog_title = "リスト" end

    def column_schemer
      [{:kind => :text, :type => String, :label => @plugin._('リスト名')},
       {:type => UserList},
       {:type => String, :widget => :input, :label => @plugin._('リストの名前')},
       {:type => String, :widget => :input, :label => @plugin._('リスト説明')},
       {:type => TrueClass, :widget => :boolean, :label => @plugin._('公開')},
      ].freeze
    end

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

  end
end
