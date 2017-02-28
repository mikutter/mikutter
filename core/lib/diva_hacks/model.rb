# -*- coding: utf-8 -*-
require_relative 'model/identity'
require_relative 'model/memory'

module Mikutter::DivaHacks::Model
  # Entityのリストを返す。
  # ==== Return
  # Retriever::Entity::BlankEntity
  def links
    @entity ||= self.class.entity_class.new(self)
  end
  alias :entity :links
end

module Mikutter::DivaHacks::ModelExtend
  extend Gem::Deprecate
  # Modelの情報を設定する。
  # このメソッドを呼ぶと、他のプラグインがこのRetrieverを見つけることができるようになるので、
  # 抽出タブの抽出条件が追加されたり、設定で背景色が指定できるようになる
  # ==== Args
  # [new_slug] Symbol
  # [name:] String Modelの名前
  # [reply:] bool このRetrieverに、宛先が存在するなら真
  # [myself:] bool このRetrieverを、自分のアカウントによって作成できるなら真
  # [timeline:] bool 真ならタイムラインに表示することができる
  def register(new_slug,
               name: new_slug.to_s,
               reply: true,
               myself: true,
               timeline: false
              )
    @slug = new_slug.to_sym
    spec = @spec = Diva::ModelSpec.new(@slug,
                                            name.to_s.freeze,
                                            !!reply,
                                            !!myself,
                                            !!timeline
                                           ).freeze
    plugin do
      filter_retrievers do |retrievers|
        retrievers << spec
        [retrievers]
      end
    end
  end

  def plugin
    if not @slug
      raise Retriever::RetrieverError, "`#{self}'.slug is not set."
    end
    if block_given?
      Plugin.create(:"retriever_model_#{@slug}", &Proc.new)
    else
      Plugin.create(:"retriever_model_#{@slug}")
    end
  end

  # Entityクラスを設定する。
  # ==== Args
  # [klass] Class 新しく設定するEntityクラス
  # ==== Return
  # [Class] セットされた（されている）Entityクラス
  def entity_class(klass=nil)
    if klass
      @entity_class = klass
    else
      @entity_class ||= Retriever::Entity::BlankEntity
    end
  end

  # あるURIが、このModelを示すものであれば真を返す条件 _condition_ を設定する。
  # _condition_ === uri が実行され、真を返せばそのURIをこのModelで取り扱えるということになる
  # ==== Args
  # [condition] 正規表現など、URIにマッチするもの
  # ==== Return
  # self
  # ==== Block
  # 実際にURIが指し示すリソースの内容を含んだModelを作って返す
  # ===== Args
  # [uri] URI マッチしたURI
  # ===== Return
  # [Delayer::Deferred::Deferredable]
  #   ネットワークアクセスを行って取得するなど取得に時間がかかる場合
  # [self]
  #   すぐにModelを生成できる場合、そのModel
  # ===== Raise
  # [Retriever::ModelNotFoundError] _uri_ に対応するリソースが見つからなかった
  def handle(condition)       # :yield: uri
    model_slug = self.slug
    plugin do
      if condition.is_a? Regexp
        filter_model_of_uri do |uri, models|
          if condition =~ uri.to_s
            models << model_slug
          end
          [uri, models]
        end
      else
        filter_model_of_uri do |uri, models|
          if condition === uri
            models << model_slug
          end
          [uri, models]
        end
      end
    end
    if block_given?
      class << self
        define_method(:find_by_uri, Proc.new)
      end
    end
  end

  # まだそのレコードのインスタンスがない場合、それを生成して返します。
  def new_ifnecessary(hash)
    type_strict hash => tcor(self, Hash)
    result_strict(self) do
      case hash
      when self
        hash
      when Hash
        self.new(hash)
      else
        raise ArgumentError.new("incorrect type #{hash.class} #{hash.inspect}")
      end
    end
  end
  #deprecate :new_ifnecessary, 'new', 2018, 2

  def rewind(args)
    type_strict args => Hash
    result_strict(:merge){ new_ifnecessary(args) }.merge(args)
  end
  #deprecate :rewind, 'new', 2018, 2

end

module Diva
  class Model
    extend Mikutter::DivaHacks::ModelExtend
    include Mikutter::DivaHacks::Model
  end

  RetrieverError = DivaError

  deprecate_constant :RetrieverError
end
