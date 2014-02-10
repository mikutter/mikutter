# -*- coding: utf-8 -*-

require File.expand_path File.join(File.dirname(__FILE__), 'edit_window')
require File.expand_path File.join(File.dirname(__FILE__), 'extract_tab_list')

Plugin.create :extract do

  # 抽出タブオブジェクト。各キーは抽出タブIDで、値は以下のようなオブジェクト
  # name :: タブの名前
  # sexp :: 条件式（S式）
  # source :: どこのツイートを見るか（イベント名、配列で複数）
  # slug :: タイムラインとタブのスラッグ
  # id :: 抽出タブのID
  def extract_tabs
    @extract_tabs ||= {} end

  settings _("抽出タブ") do
    tablist = Plugin::Extract::ExtractTabList.new(Plugin[:extract])
    pack_start(Gtk::HBox.new.
               add(tablist).
               closeup(Gtk::VBox.new(false, 4).
                       closeup(Gtk::Button.new(Gtk::Stock::ADD).tap{ |button|
                                 button.ssc(:clicked) {
                                   Plugin.call :extract_tab_open_create_dialog
                                   true } }).
                       closeup(Gtk::Button.new(Gtk::Stock::EDIT).tap{ |button|
                                 button.ssc(:clicked) {
                                   id = tablist.selected_id
                                   if id
                                     Plugin.call(:extract_open_edit_dialog, id) end
                                   true } }).
                       closeup(Gtk::Button.new(Gtk::Stock::DELETE).tap{ |button|
                                 button.ssc(:clicked) {
                                   # TODO: confirm
                                   id = tablist.selected_id
                                   if id
                                     Plugin.call(:extract_tab_delete, id) end
                                   true } })))
    Plugin.create :extract do
      add_tab_observer = on_extract_tab_create(&tablist.method(:add_record))
      tablist.ssc(:destroy) do
        detach add_tab_observer
      end
    end
  end

  command(:extract_edit,
          name: _('抽出条件を編集'),
          condition: lambda{ |opt|
            opt.widget.slug.to_s =~ /^extract_(?:.+)$/
          },
          visible: true,
          role: :tab) do |opt|
	extract_id = opt.widget.slug.to_s.match(/^extract_(.+)$/)[1].to_i
    Plugin.call(:extract_open_edit_dialog, extract_id) if extract_tabs[extract_id]
  end

  on_extract_tab_create do |record|
    record[:id] = Time.now.to_i unless record[:id]
    slug = "extract_#{record[:id]}".to_sym
    record = record.melt
    record[:slug] = slug
    extract_tabs[record[:id]] = record.freeze
    tab(slug, record[:name]) do
      timeline slug end
    modify_extract_tabs end

  on_extract_tab_update do |record|
    extract_tabs[record[:id]] = record.freeze
    modify_extract_tabs end

  on_extract_tab_delete do |id|
    if extract_tabs.has_key? id
      deleted_tab = extract_tabs[id]
      tab(deleted_tab[:slug]).destroy
      extract_tabs.delete(id)
      modify_extract_tabs end end

  on_extract_tab_open_create_dialog do
    dialog = Gtk::Dialog.new(_("抽出タブを作成 - %{mikutter}") % {mikutter: Environment::NAME}, nil, nil,
                             [Gtk::Stock::OK, Gtk::Dialog::RESPONSE_ACCEPT],
                             [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_REJECT])
    prompt = Gtk::Entry.new
    dialog.vbox.
      add(Gtk::HBox.new(false, 8).
          closeup(Gtk::Label.new(_("名前"))).
          add(prompt).show_all)
    dialog.run{ |response|
      if Gtk::Dialog::RESPONSE_ACCEPT == response
        Plugin.call :extract_tab_create, name: prompt.text end
      dialog.destroy
      prompt = dialog = nil } end

  on_extract_open_edit_dialog do |extract_id|
    ::Plugin::Extract::EditWindow.new(extract_tabs[extract_id], self)
  end

  on_appear do |messages|
    append_message("appear", messages) end

  on_update do |s, messages|
    append_message("update", messages) end

  on_mention do |s, messages|
    append_message("mention", messages) end

  on_posted do |s, messages|
    append_message("posted", messages) end

  filter_extract_tabs_get do |tabs|
    [tabs + extract_tabs.values]
  end

  filter_extract_datasources do |datasources|
    datasources = {
      appear: _("受信したすべての投稿"),
      update: _("ホームタイムライン(全てのアカウント)"),
      mention: _("自分宛ての投稿(全てのアカウント)")
    }.merge datasources
    Service.map{ |service|
      user = service.user_obj
      datasources.merge!({ "home_timeline-#{user.id}".to_sym => "@#{user.idname}/" + _("Home Timeline"),
                           "mentions-#{user.id}".to_sym => "@#{user.idname}/" + _("Mentions")
                         })
    }
    [datasources] end

  # 抽出タブの現在の内容を保存する
  def modify_extract_tabs
    UserConfig[:extract_tabs] = extract_tabs.values
  end

  def compile(tab_id, code)
    atomic do
      @compiled ||= {}
      @compiled[tab_id] ||= ->(assign,evaluated){
        assign += "  user = message.idname\n"     if evaluated.include? "user"
        assign += "  body = message.to_s\n"       if evaluated.include? "body"
        assign += "  source = message[:source]\n" if evaluated.include? "source"
        notice "tab code: lambda{ |message|\n" + assign + "  " + evaluated + "\n}"
        eval("lambda{ |message|\n" + assign + "  " + evaluated + "\n}")
      }.("",MIKU::Primitive.new(:to_ruby_ne).call(MIKU::SymbolTable.new, code)) end end

  def destroy_compile_cache
    atomic do
      @compiled = {} end end

  def append_message(source, messages)
    type_strict source => String, messages => Enumerable
    tabs = extract_tabs.values.select{ |r| r[:sources] && r[:sources].include?(source) }
    return if tabs.empty?
    converted_messages = Messages.new(messages.map{ |message| message.retweet_source ? message.retweet_source : message })
    tabs.deach{ |record|
      begin
        timeline(record[:slug]) << converted_messages.select(&compile(record[:id], record[:sexp]))
      rescue Exception => e
        error "filter '#{record[:name]}' crash: #{e.to_s}" end } end

  (UserConfig[:extract_tabs] or []).each{ |record|
    extract_tabs[record[:id]] = record.freeze
    Plugin.call(:extract_tab_create, record) }

  extract_tabs_watcher = UserConfig.connect :extract_tabs do |key, val, before_val, id|
    destroy_compile_cache end

  on_unload do
    UserConfig.disconnect(extract_tabs_watcher) end

end

