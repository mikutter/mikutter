# -*- coding: utf-8 -*-
require_relative 'model/intent'
require_relative 'model/intent_token'

Plugin.create(:intent) do
  # 全てのIntentを列挙するためのフィルタ
  defevent :intent_catalog,
           prototype: [:<<]

  # _uri_ を開くことができる Model を列挙するためのフィルタ
  defevent :model_of_uri,
           prototype: [Diva::URI, :<<]

  # _model_slug_ を開くことができる Intent を列挙するためのフィルタ
  defevent :intent_select_by_model_slug,
           prototype: [Symbol, :<<]

  # 第二引数のリソースを、第一引数のIntentのうちどれで開くかを決められなかった時に発生する。
  # intent_selectorプラグインがこれを受け取ってダイアログとか出す
  defevent :intent_select,
           prototype: [Enumerable, tcor(Diva::URI, String, Diva::Model)]

  # IntentTokenの次にあたるintentを発生させる。
  defevent :intent_forward,
           priority: :ui_response,
           prototype: [Plugin::Intent::IntentToken]

  # _model_ を開く方法を新しく登録する。
  # ==== Args
  # [model] サポートするModel(Class)又はModelのslug(Symbol)
  # [label:]
  #   開き方を説明する文字列。
  #   あるModelを開く手段が複数ある場合、ユーザは _label_ の内容とともに、どうやって開くか選択することになる。
  #   省略した場合はpluginの名前になる
  # [slug:]
  #   このintentのslug。他のintentと重複してはならない。
  #   通常は指定しなくてもユニークなslugが割り当てられるが、同じ _model_ に二つ以上のintentを登録する場合は、同じslugが自動生成されてしまうので、ユニークな値を設定しなければならない。
  #   省略した場合はPluginとModelから自動生成される
  # [&proc]
  #   パーマリンクを開く時に、 Plugin::Intent::IntentToken を引数に呼ばれる。
  # ==== Return
  # self
  defdsl :intent do |model, label: nil, slug: nil, &proc|
    model = Diva::Model(model) unless model.is_a?(Class)
    slug ||= :"#{self.spec[:slug]}_#{model.slug}"
    label ||= (self.spec[:name] || self.spec[:slug])
    my_intent = Plugin::Intent::Intent.new(slug: slug, label: label, model_slug: model.slug)
    filter_intent_select_by_model_slug do |target_model_slug, intents|
      if model.slug == target_model_slug
        intents << my_intent
      end
      [target_model_slug, intents]
    end
    filter_intent_all do |intents|
      intents << my_intent
      [intents]
    end
    add_event(:"intent_open_#{slug}", &proc)
    self
  end

  command(:intent_open,
          name: _('開く'),
          condition: lambda{ |opt| opt.messages.size == 1 },
          visible: true,
          role: :timeline) do |opt|
    Plugin.call(:open, opt.messages.first)
  end

  on_open do |object|
    case object
    when Plugin::Intent::IntentToken
      Plugin.call("intent_open_#{object.intent.slug}", object)
    when Diva::Model
      open_model(object)
    else
      open_uri(Diva::URI!(object))
    end
  end

  on_intent_forward do |intent_token|
    case intent_token[:source]
    when Diva::Model
      open_model(intent_token[:source], token: intent_token)
    else
      open_uri(intent_token.uri, token: intent_token)
    end
  end

  # _uri_ をUI上で開く。
  # このメソッドが呼ばれたらIntentTokenを生成して、開くことを試みる。
  # open_modelのほうが高速なので、modelオブジェクトが存在するならばopen_modelを呼ぶこと。
  # ==== Args
  # [uri] 対象となるURI
  # [token:] 親となるIntentToken
  def open_uri(uri, token: nil)
    model_slugs = Plugin.filtering(:model_of_uri, uri.freeze, Set.new).last
    if model_slugs.empty?
      error "model not found to open for #{uri}"
      return
    end
    intents = model_slugs.lazy.flat_map{|model_slug|
      Plugin.filtering(:intent_select_by_model_slug, model_slug, []).last
    }
    if token
      intents = intents.reject{|intent| token.intent_ancestors.include?(intent) }
    end
    head = intents.first(2)
    case head.size
    when 0
      error "intent not found to open for #{model_slugs.to_a}"
      return
    when 1
      Plugin::Intent::IntentToken.open(
        uri: uri,
        intent: head.first,
        parent: token)
    else
      Plugin.call(:intent_select, intents, uri)
    end
  end

  # _model_ をUI上で開く。
  # このメソッドが呼ばれたらIntentTokenを生成して、開くことを試みる。
  # open_uriは、Modelが必要になった時にURIからModelの取得生成を試みるが、
  # このメソッドはヒントとして _model_ を与えるため、探索が発生せず高速に処理できる。
  # ==== Args
  # [model] 対象となるDiva::Model
  def open_model(model, token: nil)
    intents = Plugin.filtering(:intent_select_by_model_slug, model.class.slug, Set.new).last
    if token
      intents = intents.reject{|intent| token.intent_ancestors.include?(intent) }
    end
    head = intents.first(2)
    case head.size
    when 0
      open_uri(model.uri, token: token)
    when 1
      intent = head.first
      Plugin::Intent::IntentToken.open(
        uri: model.uri,
        model: model,
        intent: intent,
        parent: token)
    else
      Plugin.call(:intent_select, intents, model)
    end
  end
end
