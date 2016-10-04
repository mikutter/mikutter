# -*- coding: utf-8 -*-
require_relative 'model/intent'
require_relative 'model/intent_token'
require_relative 'model/web'

Plugin.create(:intent) do
  # _uri_ を開くことができる Model を列挙するためのフィルタ
  defevent :model_of_uri,
           prototype: [URI, :<<]

  # _model_slug_ を開くことができる Intent を列挙するためのフィルタ
  defevent :intent_select_by_model_slug,
           prototype: [Symbol, :<<]

  # _model_ を開く方法を新しく登録する。
  # ==== Args
  # [model] サポートするModelのClass
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
  defdsl :intent do |model, label: nil, slug: :"#{self.spec[:slug]}_#{model.slug}", &proc|
    label ||= (self.spec[:name] || self.spec[:slug])
    my_intent = Plugin::Intent::Intent.new(slug: slug, label: label, model_slug: model.slug)
    filter_intent_select_by_model_slug do |target_model_slug, intents|
      if model.slug == target_model_slug
        intents << my_intent
      end
      [target_model_slug, intents]
    end
    add_event(:"intent_open_#{slug}", &proc)
    self
  end

  intent Plugin::Intent::Web, label: 'Open in foreign browser' do |intent|
    Gtk.openurl(intent.model.perma_link.to_s)
  end

  on_open do |object|
    case object
    when Plugin::Intent::IntentToken
      Plugin.call("intent_open_#{object.intent.slug}", object)
    when Retriever::Model
      open_model(object)
    when String, URI
      open_uri(object.is_a?(URI) ? object : URI.parse(object))
    end
  end

  # _uri_ をUI上で開く。
  # このメソッドが呼ばれたらIntentTokenを生成して、開くことを試みる。
  # open_modelのほうが高速なので、modelオブジェクトが存在するならばopen_modelを呼ぶこと。
  # ==== Args
  # [uri] 対象となるURI
  def open_uri(uri)
    model_slugs = Plugin.filtering(:model_of_uri, uri.freeze, Set.new).last
    if model_slugs.empty?
      error "model not found to open for #{uri}"
      return
    end
    intents = model_slugs.inject(Set.new) do |memo, model_slug|
      memo.merge(Plugin.filtering(:intent_select_by_model_slug, model_slug, Set.new).last)
    end
    if intents.empty?
      error "intent not found to open for #{model_slugs.to_a}"
      return
    end
    # TODO: intents をユーザに選択させる
    intent = intents.to_a.first
    Plugin::Intent::IntentToken.open(
      uri: uri,
      intent: intent,
      parent: nil)
  end

  # _model_ をUI上で開く。
  # このメソッドが呼ばれたらIntentTokenを生成して、開くことを試みる。
  # open_uriは、Modelが必要になった時にURIからModelの取得生成を試みるが、
  # このメソッドはヒントとして _model_ を与えるため、探索が発生せず高速に処理できる。
  # ==== Args
  # [model] 対象となるRetriever::Model
  def open_model(model)
    intents = Plugin.filtering(:intent_select_by_model_slug, model.class.slug, Set.new).last
    # TODO: intents をユーザに選択させる
    intent = intents.to_a.first
    Plugin::Intent::IntentToken.open(
      uri: model.uri,
      model: model,
      intent: intent,
      parent: nil)
  end

end
