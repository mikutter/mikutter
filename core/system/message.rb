# -*- coding: utf-8 -*-

miquire :core, 'retriever', 'skin'

class Mikutter::System::Message < Retriever::Model
  include Retriever::Model::MessageMixin

  register :system_message,
           name: "System Message",
           timeline: true,
           myself: false

  field.string :description, required: true
  field.has :user, Mikutter::System::User, required: true
  field.time :created
  field.time :modified

  entity_class Retriever::Entity::URLEntity

  def initialize(value)
    value[:user] ||= Mikutter::System::User.system
    value[:modified] ||= value[:created] ||= Time.now.freeze
    super(value)
  end

  # 投稿がシステムメッセージだった場合にtrueを返す
  def system?
    true
  end

  def to_me?
    true
  end

end
