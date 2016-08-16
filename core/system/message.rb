# -*- coding: utf-8 -*-

miquire :core, 'retriever', 'skin'
miquire :lib, 'retriever/mixin/message_mixin'

class Mikutter::System::Message < Retriever::Model
  include Retriever::Model::MessageMixin

  register :system_message,
           name: "System Message"

  self.keys = [[:description, :string, true], # Message description
               [:user, Mikutter::System::User, true],       # Send by user
               [:created, :time],         # posted time
               [:modified, :time],        # updated time
              ]

  def initialize(value)
    value[:user] ||= Mikutter::System::User.system
    value[:modified] ||= value[:created] ||= Time.now.freeze
    super(value)
    @entity = Message::Entity.new(self)
  end

  def links
    @entity
  end

  # 投稿がシステムメッセージだった場合にtrueを返す
  def system?
    true
  end

end
