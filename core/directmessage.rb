miquire :core, 'retriever'

module Mikutter; end

module Mikutter::Twitter
  class DirectMessage < Retriever::Model

    register :twitter_direct_message,
             name: "Direct Message"

    self.keys = [[:id, :int, true],         # ID
                 [:text, :string, true], # Message description
                 [:user, User, true],       # Send by user
                 [:sender, User, true],       # Send by user (old)
                 [:recipient, User, true], # Received by user
                 [:exact, :bool],           # true if complete data
                 [:created, :time],         # posted time
    ]

    entity_class Retriever::Entity::TwitterEntity

    def self.memory
      @memory ||= DirectMessageMemory.new end

    def mentioned_by_me?
      false
    end

    def favorite(_)
      # Intentionally blank
    end

    def favorite?
      false
    end

    def favorited_by
      []
    end

    def favoritable?
      false
    end

    def retweet
      # Intentionally blank
    end

    def retweet?
      nil
    end

    def retweeted?
      false
    end

    def retweeted_by
      []
    end

    def retweetable?
      false
    end

    def retweet_source(_=nil)
      nil
    end

    def quoting?
      false
    end

    def has_receive_message?
      false
    end

    def to_show
      @to_show ||= self[:text].gsub(/&(gt|lt|quot|amp);/){|m| {'gt' => '>', 'lt' => '<', 'quot' => '"', 'amp' => '&'}[$1] }.freeze
    end

    def to_message
      self
    end
    alias :message :to_message

    def system?
      false
    end

    def created
      self[:created]
    end

    def modified
      self[:created]
    end

    def from_me?
      return false if system?
      Service.map(&:user_obj).include?(self[:user])
    end
    
    def to_me?
      true
    end

    def user
      self[:user]
    end

    def idname
      user[:idname]
    end

    def post(args, &block)
      Service.primary.send_direct_message({:text => args[:message], :user => self[:user]}, &block)
    end

    def repliable?
      true
    end

    def perma_link
      nil
    end

    def receive_user_screen_names
      [self[:recipient].idname]
    end

    def ancestors(force_retrieve=false)
      [self]
    end

    def ancestor(force_retrieve=false)
      ancestors(force_retrieve).last
    end
  end

  class DirectMessageMemory < Retriever::Model::Memory; end

end
