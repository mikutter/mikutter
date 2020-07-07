# -*- coding: utf-8 -*-
require_relative 'listview'

Plugin.create(:intent_selector) do
  UserConfig[:intent_selector_rules] ||= []

  on_intent_select do |intents, model|
    case model
    when Diva::Model
      intent_open(intents, model: model)
    else
      intent_open(intents, uri: Diva::URI!(model))
    end
  end

  settings(_('関連付け')) do
    intents = Plugin.filtering(:intent_all, []).first.map{|i|[i.slug.to_s, i.label]}.to_h
    models = Plugin.filtering(:retrievers, []).first.map{|s|[s[:slug].to_s,s[:name]]}.to_h.merge('' => _('（未定義）'))
    listview(
      :intent_selector_rules,
      columns: [
        [_('開く方法'), ->(record) { intents[record[:intent]] }],
        [_('対象'),     ->(record) { models[record[:model]] }],
        [_('条件'),     ->(record) { record[:str] }],
      ],
    ) do |_record|
      select(_('開く方法'), :intent, intents)
      select(_('対象'), :model, models)
      input '条件', :str
    end
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
    dialog(_('開く - %{application_name}') % {application_name: Environment::NAME}) do
      set_value(
        intent: intents.first,
        save_uri: uri.to_s,
      )
      label "%{uri}\nを開こうとしています。どの方法で開きますか？" % {uri: uri}
      select nil, :intent, mode: :radio do
        intents.each do |intent|
          option intent, intent.label
        end
      end
      multiselect(_('関連付け'), :save_flag) do
        option :save, _('次回から、次の内容から始まるURLはこの方法で開く') do
          input nil, :save_uri
        end
      end
    end.next do |response|
      if response[:intent]
        Plugin::Intent::IntentToken.open(
          uri: uri,
          model: model,
          intent: response[:intent],
          parent: nil
        )
        if response[:save_flag].include?(:save)
          add_intent_rule(
            intent: response[:intent],
            str: response[:save_uri],
            rule: 'start',
            model_slug: specified_model_slug(model))
        end
      end
    end
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
      ((record[:model] == nil) || (model_slug == record[:model].to_s)) && uri.to_s.start_with?(record[:str])
    }.map{|record|
      record[:intent].to_sym
    }
    intents.partition{|intent| intent_slugs.include?(intent.slug.to_sym) }
  end

  # _model_ のmodel slugを文字列で得る。
  # ==== Args
  # [model] Diva::Modelのインスタンス又はnil
  # ==== Return
  # [String] Modelのslug。 _model_ がnilだった場合は空文字列
  def specified_model_slug(model)
    model ? model.class.slug.to_s : ''
  end

end
