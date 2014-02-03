# -*- coding: utf-8 -*-

require File.expand_path File.join(File.dirname(__FILE__), 'edit_window')

Plugin.create :extract do

  # 抽出タブオブジェクト。各キーは抽出タブIDで、値は以下のようなオブジェクト
  # name :: タブの名前
  # sexp :: 条件式（S式）
  # source :: どこのツイートを見るか（イベント名、配列で複数）
  # slug :: タイムラインとタブのスラッグ
  # id :: 抽出タブのID
  def extract_tabs
    @extract_tabs ||= {} end

  crud = nil

  settings _("抽出タブ") do
    crud = ExtractTab.new(Plugin[:extract])
    crud.set_size_request(0, 200)
    (UserConfig[:extract_tabs] or []).each{ |record|
      iter = crud.model.append
      iter[ExtractTab::ITER_NAME] = record[:name]
      iter[ExtractTab::ITER_SEXP] = record[:sexp]
      iter[ExtractTab::ITER_SOURCE] = record[:sources]
      iter[ExtractTab::ITER_ID] = record[:id]
    }

    pack_start(Gtk::HBox.new.add(crud).closeup(crud.buttons(Gtk::VBox)))
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
    slug = "extract_#{record[:id]}".to_sym
    record = record.melt
    record[:slug] = slug
    extract_tabs[record[:id]] = record.freeze
    tab(slug, record[:name]) do
      timeline slug end
    modify_extract_tabs end

  on_extract_tab_update do |record|
    extract_tabs[record[:id]] = extract_tabs[record[:id]].merge(record).freeze
    modify_extract_tabs end

  on_extract_tab_delete do |id|
    if extract_tabs.has_key? id
      deleted_tab = extract_tabs[id]
      tab(deleted_tab[:slug]).destroy
      extract_tabs.delete(id)
      modify_extract_tabs end end

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
    datasources = {all: _("受信したすべての投稿")}.merge datasources
    Service.map{ |service|
      user = service.user_obj
      datasources.merge!({ "home_timeline-#{user.id}".to_sym => "@#{user.idname}/" + _("Home Timeline"),
                           "mentions-#{user.id}".to_sym => "@#{user.idname}/" + _("Mentions")
                         })
    }
    [datasources] end

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

  class ExtractTab < ::Gtk::CRUD
    ITER_NAME = 0
    ITER_SOURCE = 1
    ITER_SEXP = 2
    ITER_ID   = 3

    def initialize(plugin)
      type_strict plugin => Plugin
      @plugin = plugin
      super()
    end

    def column_schemer
      [{ :kind => :text,
         :widget => :input,
         :type => String,
         :label => '名前' },
       { :type => Object,
         :widget => :choosemany,
         :args => [[['appear', @plugin._('受信したすべての投稿')],
                    ['update', @plugin._('フレンドタイムライン')],
                    ['mention', @plugin._('自分宛のリプライ')],
                    ['posted', @plugin._('自分が投稿したメッセージ')]]]},
       { :type => Object,
         :widget => :message_picker },
       { :type => Integer },
      ].freeze
    end

    # レコードの配列を返す
    # ==== Return
    # レコードの配列
    def extract_tabs
      UserConfig[:extract_tabs] || {} end

    def on_created(iter)
      Plugin.call(:extract_tab_create,
                  name: iter[ITER_NAME],
                  sexp: iter[ITER_SEXP],
                  sources: iter[ITER_SOURCE],
                  id: iter[ITER_ID] = gen_uniq_id) end

    def on_updated(iter)
      Plugin.call(:extract_tab_update,
                  name: iter[ITER_NAME],
                  sexp: iter[ITER_SEXP],
                  sources: iter[ITER_SOURCE],
                  id: iter[ITER_ID]) end

    def on_deleted(iter)
      Plugin.call(:extract_tab_delete, iter[ITER_ID]) end

    def gen_uniq_id(uniq_id = Time.now.to_i)
      if extract_tabs.any?{ |x| x[:id] == uniq_id }
        gen_uniq_id(uniq_id + 1)
      else
        uniq_id end end
  end

  (UserConfig[:extract_tabs] or []).each{ |record|
    extract_tabs[record[:id]] = record.freeze
    Plugin.call(:extract_tab_create, record) }

  extract_tabs_watcher = UserConfig.connect :extract_tabs do |key, val, before_val, id|
    destroy_compile_cache end

  on_unload do
    UserConfig.disconnect(extract_tabs_watcher) end

end

