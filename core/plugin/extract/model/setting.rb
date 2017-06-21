# -*- coding: utf-8 -*-

module Plugin::Extract
  def Setting(hash)
    if hash.is_a? Setting
      hash
    else
      Plugin::Extract::Setting.new(hash)
    end
  end

  class Setting < Retriever::Model
    include Retriever::Model::MessageMixin
    include Retriever::Model::UserMixin

    field.string :name, required: true
    field.int :id, required: true
    field.string :slug, required: true
    field.has :sources, [:string], required: true
    field.uri :sound
    field.bool :popup
    field.string :order
    field.uri :icon

    def initialize(hash)
      hash[:id] ||= Time.now.to_i
      hash[:slug] ||= "extract_#{hash[:id]}"
      hash[:sources] ||= []
      super(hash)
      Plugin.call(:extract_tab_create, self)
    end

    def slug
      self[:slug].to_sym
    end

    def sources
      (self[:sources] || []).map(&:to_sym)
    end

    def order
      (self[:order] || :modified).to_sym
    end

    def find_ordering_obj
      Enumerator.new{|y|
        Plugin.filtering(:extract_order, y)
      }.find{|o| o.slug == order }
    end

    def sexp
      self[:sexp]
    end

    # 引数のsourceがsourcesに含まれていれば真を返す
    def using?(source_name)
      sources.include?(source_name.to_sym)
    end

    # 更新イベントを発生させる。
    def notify_update
      Plugin.call(:extract_tab_update, self)
    end

    # この抽出タブを消去する。
    # force: に真を渡すと、確認ダイアログを表示せずに削除する。
    def delete(force: false)
      if force
        Plugin.call(:extract_tab_delete, id)
      else
        Plugin.call(:extract_tab_delete_with_confirm, id)
      end
    end

    def export_to_userconfig
      { name: name,
        id: id,
        slug: slug,
        sources: sources,
        sound: sound ? sound.to_s : nil,
        popup: popup?,
        icon: icon ? icon.to_s : nil,
        order: order,
        uri: uri.to_s,
        sexp: self[:sexp]
      }
    end

    def path
      "/#{id}"
    end
  end
end
