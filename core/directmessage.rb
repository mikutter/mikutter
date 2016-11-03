miquire :core, 'retriever'

module Mikutter; end

module Mikutter::Twitter
  class DirectMessage < Retriever::Model
    include Retriever::Model::MessageMixin

    register :twitter_direct_message,
             name: "Direct Message"

    field.int    :id, required: true                        # ID
    field.string :text, required: true                      # Message description
    field.has    :user, User, required: true                # Send by user
    field.has    :sender, User, required: true              # Send by user (old)
    field.has    :recipient, User, required: true           # Received by user
    field.bool   :exact                                     # true if complete data
    field.time   :created                                   # posted time

    entity_class Retriever::Entity::TwitterEntity

    def self.memory
      @memory ||= DirectMessageMemory.new end

    def mentioned_by_me?
      false
    end

    def to_show
      @to_show ||= self[:text].gsub(/&(gt|lt|quot|amp);/){|m| {'gt' => '>', 'lt' => '<', 'quot' => '"', 'amp' => '&'}[$1] }.freeze
    end

    def from_me?
      return false if system?
      Service.map(&:user_obj).include?(self[:user])
    end

    def to_me?
      true
    end

    def post(args, &block)
      Service.primary.send_direct_message({:text => args[:message], :user => self[:user]}, &block)
    end

    def repliable?
      true
    end

    def receive_user_screen_names
      [self[:recipient].idname]
    end
  end

  class DirectMessageMemory < Retriever::Model::Memory; end

end
