# -*- coding:utf-8 -*-
# 公式リスト

require File.expand_path File.join(File.dirname(__FILE__), 'liststream')

require 'set'

Module.new do

  @lists = []
  @plugin = Plugin::create(:lists)
  @tabclass = Class.new(Addon.gen_tabclass){
    def initialize(*args)
      super(*args)
      if list.member.empty?
        @service.list_members( list_id: list[:id],
                               public: list[:public],
                               cache: true).next{ |users|
          list.add_member(users) if users
        }.terminate("リスト #{list[:full_name]} (##{list[:id]}) のメンバーの取得に失敗しました") end end

    def list
      @options[:list] end

    # リストのTLに _messages_ を入れる。
    # メンバーにないUserのMessageが含まれている場合、そのUserをリストに加入させる
    # ==== Args
    # [messages]
    #   Message の配列。
    #   このリストのメンバーにないUserのMessageが含まれている場合、そのUserをリストに加入させる
   def update_member_messages!(messages)
     messages.each{ |m|
       list.add_member(m[:user]) if not list.member?(m[:user]) }
      update(messages, false) end

    # リストのTLに、 _messages_ を入れる。
    # ==== Args
    # [messages] Message の配列
    # [filtering] メンバー以外が投稿したMessageが含まれている場合、無視される
    def update(messages, filtering = true)
      if(filtering)
        super(messages.select{ |m|
                idnames = m.receive_user_screen_names
                if idnames.empty?
                  list.member?(m[:user])
                else
                  list.member?(m[:user]) and list.member.any?{ |user| idnames.include?(user[:idname]) } end })
      else
        super(messages)
      end
    end

    def suffix
      '(List)' end

    # REST APIで、リストの最新のツイートを取得する。
    # また、ここに出現したユーザは、全てリストのメンバーであるとみなされ、リストに追加される。
    def rewind(use_cache=false)
      @service.list_statuses(:id => list[:id],
                             :cache => use_cache).next{ |res|
        update_member_messages!(res) if res.is_a? Array
      }.terminate
      self end }

  def self.boot
    @plugin.add_event(:boot){ |service|
      Plugin.call(:setting_tab_regist, settings, 'リスト')
      @service = service
      @count = 0
      update(UserConfig[:use_cache_first_query]) }

    @plugin.add_event(:period){ |service|
      @count += 1
      if(@count >= (UserConfig[:retrieve_interval_list_timeline] || 60))
        update
        @count = 0 end }

    @plugin.add_event(:before_exit_api_section){
      update_member
    }

    @plugin.add_event(:list){ |query|
      add_tab(query, query) }

    @plugin.add_event(:appear){ |messages|
      @tabclass.tabs.each{ |tab|
        tab.update(messages) } }

    @plugin.add_event_hook(:list_data){ |event|
      event.call(@service, @lists) }

    @plugin.add_event_filter(:displayable_lists) { |lists|
      [lists + displayable_lists.map(&method(:list_detail))] }

    exist_lists = []
    @plugin.add_event(:list_data){ |service, lists|
      lists_id = lists.map{ |l| l['id'] }
      created_lists = lists_id - exist_lists
      destroy_lists = exist_lists - lists_id
      Plugin.call(:list_created, service, created_lists.map{ |id| list_datail(id) }) if created_lists.empty?
      Plugin.call(:list_destroy, service, destroy_lists) if destroy_lists.empty?
      exist_lists = lists
    }
  end

  def self.update(get_cache = false)
    param = {:cache => false, :user => @service.user_obj}
    @service.lists(param).next{ |lists|
      if lists
        set_available_lists(lists)
        remove_unmarked{
          lists.each{ |list|
            add_tab(list) } } end }.terminate
  end

  def self.update_member
    Thread.new do
      Plugin.filtering(:displayable_lists, Set.new).first.each{ |list|
        if list
          @service.list_members( list_id: list[:id],
                                 public: list[:public],
                                 cache: :keep).next{ |users|
            list[:member] = users if users
          }.terminate("リスト #{list[:full_name]} (##{list[:id]}) のメンバーの取得に失敗しました") end } end end

  def self.remove_unmarked
    Gtk::Lock.synchronize{
      @tabclass.tabs.each{ |tab|
        tab.mark = false }
      yield
      @tabclass.tabs.each{ |tab|
        tab.remove if not tab.mark } } end

  def self.add_tab(record)
    tab = @tabclass.tabs.find{ |tab| tab.name == record['full_name'] }
    if tab
      tab.rewind.mark = true
    else
      if list_display?(record['id'])
        Gtk::Lock.synchronize{
          @tabclass.new(record['full_name'], @service,
                        :list => record,
                        :icon => MUI::Skin.get("list.png")).rewind(true) } end end end

  def self.remove_tab(record)
    tab = @tabclass.tabs.find{ |tab| tab.name == record['full_name'] }
    tab.remove if tab
    self end

  def self.list_detail(id)
    @lists.find{ |list| list['id'] == id } end

  def self.displayable_lists
    @plugin.at(:display_lists, []) end

  def self.set_displayable_lists(list)
    @plugin.store(:display_lists, list.uniq) end

  def self.available_lists
    @lists.map{ |list| list['id'] } end

  def self.set_available_lists(list)
    notice list.map{ |l| l[:slug] }.inspect
    @lists = list.freeze
    Plugin::call(:list_data, @service, @lists)
    Delayer.new{ settings }
    self end

  def self.hidden_lists
    available_lists - display_lists end

  def self.list_display?(id)
    displayable_lists.include?(id.to_i) end

  def self.set_display(id, flag)
    id = id.to_i
    if flag
      set_displayable_lists(displayable_lists + [id])
      add_tab(list_detail(id))
    else
      set_displayable_lists(displayable_lists - [id])
      remove_tab(list_detail(id)) end end

  def self.delete_list(list_id, view)
    @service.delete_list(list_id: list_id){ |event, list|
      notice [event, list].inspect
      if event == :success
        notice :success
        begin
          view.model.each{ |model, path, iter|
            notice [iter[1], iter[2].to_i, list_id.to_i].inspect
            view.model.remove(iter) if iter[2].to_i == list_id.to_i }
        rescue => e
          warn e
        end
      end } end

  def self.settings
    if defined? @setting_container
      @setting_container.remove(@setting_container.child)
    else
      @setting_container = Gtk::EventBox.new end
    container = Gtk::ListList.new{ |iter| set_display(iter[2], iter[0] = !iter[0]) }
    container.signal_connect('button_release_event'){ |widget, event|
      if (event.button == 3)
        menu_pop(container)
        true end }
    available_lists.each{ |list_id|
      iter = container.model.append
      iter[0] = list_display?(list_id)
      iter[1] = list_detail(list_id)['full_name']
      iter[2] = list_id }
    @setting_container.add(container).show_all end

  def self.popupwindow_create_list(list_name = "", list_desc = "", public = true)
    container = Gtk::VBox.new.
      closeup(Mtk.input(lambda{ |new| if new then list_name = new else list_name end },
                        'リストの名前')){ |c, w| w.max_length = 25 }.
      closeup(Mtk.input(lambda{ |new| if new then list_desc = new else list_desc end },
                        '説明')){ |c, w| w.max_length = 100 }.
      closeup(Mtk.boolean(lambda{ |new| if new === nil then public else public = new end }, '公開'))
    lambda{ {
        :container => container,
        :mode => public,
        :description => list_desc,
        :name => list_name } }
  end

  def self.create_dialog(title, container)
    dialog = Gtk::Dialog.new("#{title} - " + Environment::NAME)
    dialog.set_size_request(400, 300)
    dialog.window_position = Gtk::Window::POS_CENTER
    dialog.vbox.pack_start(container, true, true, 30)
    dialog.add_button(Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK)
    dialog.add_button(Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL)
    dialog end

  def self.menu_pop(widget)
    contextmenu = Gtk::ContextMenu.new
    contextmenu.registmenu("リストを作成"){ |optional, w|
      popup = popupwindow_create_list
      dialog = create_dialog('リストを作成', popup.call[:container])
      dialog.signal_connect('response'){ |widget, response|
        if response == Gtk::Dialog::RESPONSE_OK
          param = popup.call
          param[:user] = {:idname => @service.user}
          @service.add_list(param){ |event, list|
            if event == :success and list
              lists = @lists.dup
              lists.push(list)
              set_available_lists(lists) end } end
        Gtk::Window.toplevels.first.sensitive = true
        dialog.hide_all.destroy
        Gtk::main_quit
      }
      Gtk::Window.toplevels.first.sensitive = false
      dialog.show_all
      Gtk::main
    }

    contextmenu.registmenu("リストを編集"){ |optional, w|
      catch(:end){
        w.view.selection.selected_each {|model, path, iter|
          list = list_detail(iter[2])
          popup = popupwindow_create_list(list[:name], list[:description], list[:mode])
          dialog = create_dialog('リストを編集', popup.call[:container])
          dialog.signal_connect('response'){ |widget, response|
            if response == Gtk::Dialog::RESPONSE_OK
              param = popup.call
              list[:name] = param[:name]
              list[:description] = param[:description]
              list[:mode] = param[:mode]
              @service.update_list(list){ |event, list|
                notice [event, list].inspect
                if event == :success and list
                  iter[1] = list[:full_name] end }
            end
            Gtk::Window.toplevels.first.sensitive = true
            dialog.hide_all.destroy
            Gtk::main_quit
          }
          Gtk::Window.toplevels.first.sensitive = false
          dialog.show_all
          Gtk::main
          throw :end
        }
      }
    }

    contextmenu.registmenu("リストを削除"){ |optional, w|
      w.view.selection.selected_each {|model, path, iter|
        if Gtk::Dialog.confirm("リスト\"#{iter[1]}\"を本当に削除しますか？\n" +
                               "一度削除するともうもどってこないよ。")
          delete_list(iter[2].to_i, widget.view) end } }
    contextmenu.popup(widget, widget)
  end

  boot
end
