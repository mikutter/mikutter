# -*- coding: utf-8 -*-

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

  settings "抽出タブ" do
    crud = ExtractTab.new
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

  def modify_extract_tabs
    UserConfig[:extract_tabs] = extract_tabs.values
  end

  def append_message(source, messages)
    type_strict source => String, messages => Enumerable
    tabs = extract_tabs.values.select{ |r| r[:sources] && r[:sources].include?(source) }
    return if tabs.empty?
    messages.each{ |message|
      message = message.retweet_source if message.retweet_source
      table = MIKU::SymbolTable.new(nil,
                                    :user => MIKU::Cons.new(message.idname, nil),
                                    :body => MIKU::Cons.new(message.to_s, nil),
                                    :source => MIKU::Cons.new(message[:source] || "", nil),
                                    :message => MIKU::Cons.new(message, nil))
      tabs.each{ |record|
        begin
          timeline(record[:slug]) << message if miku(record[:sexp], table)
        rescue Exception => e
          error "filter '#{record[:name]}' crash: #{e.to_s}" end
      } } end

  class ExtractTab < ::Gtk::CRUD
    ITER_NAME = 0
    ITER_SOURCE = 1
    ITER_SEXP = 2
    ITER_ID   = 3
    def column_schemer
      [{ :kind => :text,
         :widget => :input,
         :type => String,
         :label => '名前' },
       { :type => Object,
         :widget => :choosemany,
         :args => [[['appear', '受信したすべての投稿'],
                    ['update', 'フレンドタイムライン'],
                    ['mention', '自分宛のリプライ'],
                    ['posted', '自分が投稿したメッセージ']]]},
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

end

