miquire :core, 'entity'
miquire :mui, 'miracle_paintable'

module Plugin::DirectMessage
  class Model < Retriever::Model
    include Gtk::MiraclePaintable

    self.keys = [[:id, :int, true],         # ID
                 [:text, :string, true], # Message description
                 [:user, User, true],       # Send by user
                 [:sender, User, true],       # Send by user (old)
                 [:recipient, User, true], # Received by user
                 [:exact, :bool],           # true if complete data
                 [:created, :time],         # posted time
    ]

    def initialize(value)
      super(value)
      @entity = Message::Entity.new(self)
    end

    def links
      @entity
    end
    alias :entity :links

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

    def retweet?
      nil
    end

    def retweeted?
      false
    end

    def retweeted_by
      []
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

    def system?
      false
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

    def post(args)
      Service.primary.send_direct_message({:text => args[:message], :user => self[:user]}, &Proc.new)
    end
  end

  class ModelRetriever < Service::ServiceRetriever
  end
end
