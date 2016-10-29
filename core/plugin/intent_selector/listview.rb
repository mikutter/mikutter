# -*- coding: utf-8 -*-

module Plugin::IntentSelector
  class IntentSelectorListView < ::Gtk::CRUD
    COLUMN_INTENT_LABEL = 0
    COLUMN_MODEL_LABEL = 1
    COLUMN_STRING = 2
    COLUMN_INTENT = 3
    COLUMN_MODEL = 4
    COLUMN_UUID = 5

    def initialize
      super
      intents = intent_catalog
      models = model_catalog
      UserConfig[:intent_selector_rules].each do |record|
        iter = model.model.append
        iter[COLUMN_INTENT] = record[:intent]
        iter[COLUMN_INTENT_LABEL] = intents[record[:intent].to_sym]
        iter[COLUMN_MODEL] = record[:model]
        iter[COLUMN_MODEL_LABEL] = models[record[:model].to_s]
        iter[COLUMN_STRING] = record[:str]
        iter[COLUMN_UUID] = record[:uuid]
      end
    end

    def initialize_model
      set_model(Gtk::TreeModelFilter.new(Gtk::ListStore.new(*column_schemer.flatten.map{|x| x[:type]})))
      model.set_visible_func{ |model, iter|
        if defined?(@filter_entry) and @filter_entry
          [COLUMN_INTENT, COLUMN_INTENT_LABEL, COLUMN_MODEL, COLUMN_MODEL_LABEL, COLUMN_STRING].any?{ |column| iter[column].to_s.include?(@filter_entry.text) }
        else
          true end }
    end

    def column_schemer
      [{kind: :text, type: Symbol, expand: true, label: _('開く方法')},
       {kind: :text, type: String, expand: true, label: _('対象')},
       {kind: :text, type: String, widget: :input, expand: true, label: _('条件')},
       {type: Symbol, widget: :chooseone, args: [intent_catalog], label: _('開く方法')},
       {type: String, widget: :chooseone, args: [model_catalog], label: _('対象')},
       {type: String},
      ].freeze
    end

    def on_created(iter)
      iter[COLUMN_UUID] = SecureRandom.uuid
      iter[COLUMN_INTENT_LABEL] = intent_catalog[iter[COLUMN_INTENT].to_sym]
      iter[COLUMN_MODEL_LABEL] = model_catalog[iter[COLUMN_MODEL].to_s]
      UserConfig[:intent_selector_rules] += [{
        intent: iter[COLUMN_INTENT].to_sym,
        model: iter[COLUMN_MODEL],
        str: iter[COLUMN_STRING],
        rule: 'start',
        uuid: iter[COLUMN_UUID]
      }]
    end

    def on_updated(iter)
      iter[COLUMN_INTENT_LABEL] = intent_catalog[iter[COLUMN_INTENT].to_sym]
      iter[COLUMN_MODEL_LABEL] = model_catalog[iter[COLUMN_MODEL].to_s]
      UserConfig[:intent_selector_rules] = UserConfig[:intent_selector_rules].map do |record|
        if record[:uuid] == iter[COLUMN_UUID]
          record.merge(
            intent: iter[COLUMN_INTENT].to_sym,
            model: iter[COLUMN_MODEL],
            str: iter[COLUMN_STRING])
        else
          record
        end
      end
    end

    def on_deleted(iter)
      UserConfig[:intent_selector_rules] = UserConfig[:intent_selector_rules].reject do |record|
        record[:uuid] == iter[COLUMN_UUID]
      end
    end

    def filter_entry
      @filter_entry ||= Gtk::Entry.new.tap do |entry|
        entry.primary_icon_pixbuf = Gdk::WebImageLoader.pixbuf(MUI::Skin.get("search.png"), 24, 24)
        entry.ssc(:changed, self, &gen_refilter)
      end
    end

    private

    def gen_refilter
      proc do
        model.refilter
      end
    end

    def _(str)
      Plugin[:intent_selector]._(str)
    end

    def intent_catalog
      Hash[Plugin.filtering(:intent_all, []).first.map{|i|[i.slug, i.label]}]
    end

    def model_catalog
      Hash[Plugin.filtering(:retrievers, []).first.map{|s|[s[:slug].to_s,s[:name]]}].merge('': _('（未定義）'))
    end

  end
end
