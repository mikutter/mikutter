# -*- coding: utf-8 -*-

Module.new do

  def self.boot
    plugin = Plugin.create(:extract)
    plugin.add_event(:boot){ |service|
      Plugin.call(:setting_tab_regist, ExtractTab.new(service), '抽出タブ') }
  end

  class ExtractTab < Gtk::CRUD
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

    def initialize(service)
      @service = service
      super()
      tabs = extract_tabs.melt
      tabs.each_with_index{ |record, index|
        unless record.has_key?(:id)
          tabs[index][:id] = record[:id] = gen_uniq_id end
        tabclass.new(record[:name], service, record)
        iter = model.append
        iter[ITER_NAME] = record[:name]
        iter[ITER_SEXP] = record[:sexp]
        iter[ITER_SOURCE] = record[:sources]
        iter[ITER_ID] = record[:id] }
      commit(tabs)
      boot_plugin
    end

    def gen_uniq_id(uniq_id = Time.now.to_i)
      if extract_tabs.any?{ |x| x[:id] == uniq_id }
        gen_uniq_id(uniq_id + 1)
      else
        uniq_id end end

    def extract_tabs
      (UserConfig[:extract_tabs] or []) end

    def on_created(iter)
      tabs = extract_tabs.melt
      record = {
        :name => iter[ITER_NAME],
        :sexp => iter[ITER_SEXP],
        :sources => iter[ITER_SOURCE],
        :id => iter[ITER_ID] = gen_uniq_id }.freeze
      tabs.push(record)
      tabclass.new(record[:name], @service, record)
      commit tabs end

    def on_updated(iter)
      tabs = extract_tabs.melt
      record = tabs[tabs.index{|x| x[:id] == iter[ITER_ID] }] = {
        :name => iter[ITER_NAME],
        :sexp => iter[ITER_SEXP],
        :sources => iter[ITER_SOURCE],
        :id => iter[ITER_ID] }
      tab = tabclass.tabs.find{|x| x.options[:id] == iter[ITER_ID]}
      if tab
        tab.change_options(record) end
      commit tabs end

    def on_deleted(iter)
      tabs = extract_tabs.melt
      tabs.delete_if{|x| x[:id] == iter[ITER_ID]}
      tab = tabclass.tabs.find{|x| x.options[:id] == iter[ITER_ID]}
      if tab
        tab.remove end
      commit tabs end

    private

    def commit(tabs)
      UserConfig[:extract_tabs] = tabs.freeze
    end

    def hook_plugin(event)
      Plugin.create(:extract).add_event(event){ |service, messages|
        tabclass.tabs.deach{ |tab| tab.__send__("event_#{event}", messages) } }
    end

    def boot_plugin
      [:update,:mention,:posted].each{ |event| hook_plugin(event) }
      Plugin.create(:extract).add_event(:appear){ |messages|
        tabclass.tabs.deach{ |tab| tab.__send__("event_appear", messages) } }
    end

    def tabclass
      @tabclass ||= Class.new(Addon.gen_tabclass){
        def on_create
          super
          focus end

        def self.define_event_hook(event)
          define_method("event_#{event}"){ |messages|
            if options[:sources] and options[:sources].include?(event.to_s) and (not destroyed?)
              update(messages.select{ |message|
                       message = message.retweet_source if message.retweet_source
                       if message.is_a? Message
                         st = MIKU::SymbolTable.new(nil,
                                                    :user => MIKU::Cons.new(message.idname, nil),
                                                    :body => MIKU::Cons.new(message.to_s, nil),
                                                    :source => MIKU::Cons.new(message[:source], nil),
                                                    :message => MIKU::Cons.new(message, nil))
                         miku(options[:sexp], st) end }) end } end

        [:appear,:update,:mention,:posted].each{ |event| define_event_hook(event) }

        def change_options(option)
          @options = @options.melt
          @options[:sexp] = option[:sexp]
          # TODO: 名前変更を実装する
        end
      }
    end
  end

  boot

end

