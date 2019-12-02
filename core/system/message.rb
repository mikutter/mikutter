# -*- coding: utf-8 -*-

require 'skin'
require 'lib/diva_hacks'

class Mikutter::System::Message < Diva::Model
  include Diva::Model::MessageMixin

  register :system_message,
           name: "System Message",
           timeline: true,
           myself: false

  field.string :description, required: true
  field.has :user, Mikutter::System::User, required: true
  field.time :created
  field.time :modified

  entity_class Diva::Entity::URLEntity

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
