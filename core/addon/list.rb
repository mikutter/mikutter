# -*- coding:utf-8 -*-
# 公式リスト

miquire :addon, 'addon'

require 'set'

Module.new do

  @lists = []
  @plugin = Plugin::create(:lists)
  @tabclass = Class.new(Addon.gen_tabclass){
    attr_reader :users
    def initialize(*args)
      super(*args)
      @users = Set.new
      @service.call_api(:list_members,
                        :id => @options[:id],
                        :user => @service.user,
                        :cache => true){ |users|
        if users
          @users.merge(users.map{ |u| u[:id].to_i })
        else
          remove end } end

    def update(messages)
      messages.each{ |m|
        id = m[:user][:id]
        @users << m[:user][:id].to_i if not @users.any?{ |uid| uid == id } }
      super(messages) end

    def suffix
      '(List)' end

    def rewind(use_cache=false)
      @service.call_api(:list_statuses,
                        :id => @options[:id],
                        :mode => @options[:mode],
                        :cache => use_cache,
                        :user => @service.user){ |res|
        Gtk::Lock.synchronize{
          update(res) if res.is_a? Array } }
      self end }

  def self.boot
    @plugin.add_event(:boot){ |service|
      Plugin.call(:setting_tab_regist, settings, 'リスト')
      @service = service
      @count = 0
      update(true) }

    @plugin.add_event(:period){ |service|
      @count += 1
      if(@count >= UserConfig[:retrieve_interval_search])
        update
        @count = 0 end }

    @plugin.add_event(:list){ |query|
      add_tab(query, query) }

    @plugin.add_event(:appear){ |messages|
      @tabclass.tabs.each{ |tab|
        tab.update(messages.select{ |m| tab.users.include?(m[:user][:id].to_i) }) } } end

  def self.update(get_cache = false)
    param = {:cache => false, :user => @service.user}
    @service.call_api(:lists, param){ |lists|
      if lists
        @service.call_api(:list_subscriptions, param){ |subscriptions|
          if subscriptions
            lists.concat(subscriptions)
            set_available_lists(lists)
            remove_unmarked{
              lists.each{ |list|
                add_tab(list) } } end } end } end

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
                        :id => record['id'],
                        :mode => record['mode.to_sym'],
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
    @lists = list
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
    @service.delete_list(list_detail(list_id)){ |event, list|
      if event == :success
        p :delete
        view.each{ |model, path, iter|
          view.remove(iter) if iter[2].to_i == list_id.to_i } end } end

  def self.settings
    if defined? @setting_container
      @setting_container.remove(@setting_container.child)
    else
      @setting_container = Gtk::EventBox.new end
    container, store, toggled = gen_listview
    toggled.signal_connect('toggled'){ |toggled, path|
      iter = store.get_iter(path)
      set_display(iter[2], iter[0] = !iter[0]) }
    container.signal_connect('button_release_event'){ |widget, event|
      if (event.button == 3)
        menu_pop(container)
        true end }
    available_lists.each{ |list_id|
      iter = store.append
      iter[0] = list_display?(list_id)
      iter[1] = list_detail(list_id)['full_name']
      iter[2] = list_id }
    @setting_container.add(container).show_all end

  def self.gen_listview
    box = Gtk::ListStore.new(TrueClass, String, Integer)
    treeview = Gtk::TreeView.new(box)

    toggled = Gtk::CellRendererToggle.new
    col = Gtk::TreeViewColumn.new('表示', toggled, :active => 0)
    col.resizable = false
    treeview.append_column col

    col = Gtk::TreeViewColumn.new('ユーザID', Gtk::CellRendererText.new, :text => 1)
    col.resizable = true
    treeview.append_column col
    return treeview, box, toggled end

    def self.menu_pop(widget)
      contextmenu = Gtk::ContextMenu.new
      contextmenu.registmenu("リストを削除"){ |optional, w|
        w.selection.selected_each {|model, path, iter|
          delete_list(iter[2], widget) } }
      contextmenu.popup(widget, widget)
    end

  boot
end
