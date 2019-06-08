# -*- coding: utf-8 -*-
require_relative 'user'

module Plugin::Twitter
  class DirectMessage < Diva::Model
    include Diva::Model::MessageMixin

    register :twitter_direct_message,
             name: "Direct Message",
             timeline: true

    field.int    :id, required: true                        # ID
    field.string :text, required: true                      # Message description
    field.has    :user, Plugin::Twitter::User, required: true                # Send by user
    field.has    :sender, Plugin::Twitter::User, required: true              # Send by user (old)
    field.has    :recipient, Plugin::Twitter::User, required: true           # Received by user
    field.bool   :exact                                     # true if complete data
    field.time   :created                                   # posted time

    alias_method :body, :text

    def self.memory
      @memory ||= DirectMessageMemory.new end

    def mentioned_by_me?
      false
    end

    def to_show
      @to_show ||= self[:text].gsub(/&(gt|lt|quot|amp);/){|m| {'gt' => '>', 'lt' => '<', 'quot' => '"', 'amp' => '&'}[$1] }.freeze
    end

    def description
      self[:text].to_s.gsub(Plugin::Twitter::Message::DESCRIPTION_UNESCAPE_REGEXP, &Plugin::Twitter::Message::DESCRIPTION_UNESCAPE_RULE)
    end

    def from_me?(world = Enumerator.new{|y| Plugin.filtering(:worlds, y) })
      case world
      when Enumerable
        world.any?(&method(:from_me?))
      when Diva::Model
        world.class.slug == :twitter && world.user_obj == self.user
      end
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

  class DirectMessageMemory < Diva::Model::Memory
    def initialize
      super(Plugin::Twitter::DirectMessage)
    end
  end

end
