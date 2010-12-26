miquire :addon, 'addon'

Module.new do

  def self.boot
    plugin = Plugin.create(:extract)
    plugin.add_event(:boot){ |service|
      Plugin.call(:setting_tab_regist, ExtractTab.new(service), '抽出タブ') }
  end

  class ExtractTab < Gtk::CRUD
    ITER_NAME = 0
    ITER_SEXP = 1
    ITER_ID   = 2
    def column_schemer
      [{:kind => :text, :widget => :input, :type => String, :label => '名前'},
       {:type => Object, :widget => :message_picker},
       {:type => Integer},
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
        iter[ITER_ID] = record[:id] }
      commit(tabs)
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
        :id => iter[ITER_ID] = gen_uniq_id }.freeze
      tabs.push(record)
      tabclass.new(record[:name], @service, record)
      commit tabs end

    def on_updated(iter)
      tabs = extract_tabs.melt
      record = tabs[tabs.index{|x| x[:id] == iter[ITER_ID] }] = {
        :name => iter[ITER_NAME],
        :sexp => iter[ITER_SEXP],
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

    def tabclass
      @tabclass ||= Class.new(Addon.gen_tabclass){
        def on_create
          super
          @update_event_id = Plugin.create(:extract).add_event(:update){ |service, messages|
            unless(destroyed?)
              update(messages.select{ |message|
                       st = MIKU::SymbolTable.new(nil,
                                                  :user => MIKU::Cons.new(message.user.idname, nil),
                                                  :body => MIKU::Cons.new(message.to_show, nil),
                                                  :message => MIKU::Cons.new(message, nil))
                       miku(options[:sexp], st) }) end }
          focus end

        def on_remove
          Plugin.create(:extract).detach(:update, @update_event_id)
        end

        def change_options(option)
          @options[:sexp] = option[:sexp]
          # TODO: 名前変更を実装する
        end

      }
    end
  end

  boot

end
