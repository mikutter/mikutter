# -*- coding: utf-8 -*-
require_relative 'listview'

Plugin.create(:intent_selector) do
  UserConfig[:intent_selector_rules] ||= []

  on_intent_select do |intents, model|
    case model
    when Retriever::Model
      intent_open(intents, model: model)
    when URI
      intent_open(intents, uri: model)
    when String
      intent_open(intents, uri: URI.parse(model))
    end
  end

  settings(_('関連付け')) do
    listview = Plugin::IntentSelector::IntentSelectorListView.new
    pack_start(Gtk::VBox.new(false, 4).
                 closeup(listview.filter_entry).
                 add(Gtk::HBox.new(false, 4).
                       add(listview).
                       closeup(listview.buttons(Gtk::VBox))))
  end

  # _model:_ または _uri:_ を開くintentを _intents_ の中から選び出し、その方法で開く。
  # このメソッドは、まず設定されたルールでintentを選出し、一つにintentが定まれば直ちにそれで開く。
  # 候補が一つに絞れなかった場合は、intent選択ダイアログを表示して、ユーザに決定を仰ぐ。
  # ==== Args
  # [intents] Intent modelの配列
  # [model:] 開くModel。 _uri:_ しかわからない場合は、省略してもよい
  # [uri:] 開くURI。 _model:_ を渡している場合は、省略してもよい
  def intent_open(intents, model: nil, uri: model.uri)
    recommended, suggested = divide_intents(intents, uri, specified_model_slug(model))
    if recommended.size == 1
      Plugin::Intent::IntentToken.open(
        uri: uri,
        model: model,
        intent: recommended.first,
        parent: nil)
    else
      intent_choose_dialog(recommended + suggested, model: model, uri: uri)
    end
  end

  def intent_choose_dialog(intents, model: nil, uri: model.uri)
    dialog = Gtk::Dialog.new('開く - %{application_name}' % {application_name: Environment::NAME})
    dialog.window_position = Gtk::Window::POS_CENTER
    dialog.add_button(Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK)
    dialog.add_button(Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL)
    dialog.vbox.closeup(Gtk::Label.new("%{uri}\nを開こうとしています。どの方法で開きますか？" % {uri: uri}, false))
    intent_token_builder = {
      uri: uri,
      model: model,
      intent: nil,
      parent: nil }
    intents.inject(nil) do |group, intent|
      if group
        radio = Gtk::RadioButton.new(group, intent.label)
      else
        intent_token_builder[:intent] = intent
        radio = Gtk::RadioButton.new(intent.label) end
      radio.ssc(:toggled) do |w|
        intent_token_builder[:intent] = intent
        false
      end
      radio.ssc(:activate) do |w|
        intent_token_builder[:intent] = intent
        dialog.signal_emit(:response, Gtk::Dialog::RESPONSE_OK)
        false
      end
      dialog.vbox.closeup(radio)
      group || radio
    end
    saving_rule_checkbox(dialog, intent_token_builder, specified_model_slug(model))
    dialog.ssc(:response) do |w, response_id|
      if response_id == Gtk::Dialog::RESPONSE_OK and intent_token_builder[:intent]
        Plugin::Intent::IntentToken.open(**intent_token_builder)
      end
      w.destroy
      false
    end
    dialog.show_all
  end

  def saving_rule_checkbox(dialog, intent_token_builder, model_slug)
    save_check = Gtk::CheckButton.new(_('次回から、次の内容から始まるURLはこの方法で開く'))
    rule = Gtk::Entry.new.set_text(intent_token_builder[:uri].to_s)
    rule.sensitive = false
    save_check.ssc(:toggled) do |widget|
      rule.sensitive = widget.active?
      false
    end
    dialog.ssc(:response) do |w, response_id|
      if response_id == Gtk::Dialog::RESPONSE_OK and intent_token_builder[:intent] and save_check.active?
        add_intent_rule(intent: intent_token_builder[:intent],
                        str: rule.text,
                        rule: 'start',
                        model_slug: model_slug)
      end
      false
    end
    dialog.vbox.
      closeup(save_check).
      closeup(rule)
  end

  def add_intent_rule(intent:, str:, rule:, model_slug:)
    unless UserConfig[:intent_selector_rules].any?{|r| r[:intent].to_sym == intent.slug && r[:str] == str && r[:rule] == rule }
      UserConfig[:intent_selector_rules] += [{uuid: SecureRandom.uuid, intent: intent.slug, model: model_slug, str: str, rule: rule}]
    end
  end

  # intent の配列を受け取り、ユーザが過去に入力したルールに基づき、
  # recommendedとsuggestedに分ける
  # ==== Args
  # [intents] スキャン対象のintent
  # [uri] リソースのURI
  # [model_slug] 絞り込みに使うModelのslug。
  # ==== Return
  # 条件に対して推奨されるintentの配列と、intentsに指定されたそれ以外の値の配列
  def divide_intents(intents, uri, model_slug)
    intent_slugs = UserConfig[:intent_selector_rules].select{|record|
      model_slug == record[:model].to_s && uri.to_s.start_with?(record[:str])
    }.map{|record|
      record[:intent].to_sym
    }
    intents.partition{|intent| intent_slugs.include?(intent.slug) }
  end

  # _model_ のmodel slugを文字列で得る。
  # ==== Args
  # [model] Retriever::Modelのインスタンス又はnil
  # ==== Return
  # [String] Modelのslug。 _model_ がnilだった場合は空文字列
  def specified_model_slug(model)
    model ? model.class.slug.to_s : ''
  end

end
