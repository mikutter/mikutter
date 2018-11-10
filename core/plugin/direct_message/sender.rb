# -*- coding: utf-8 -*-

module Plugin::DirectMessage
  class Sender
    def self.slug
      :twitter_directmessage_posting
    end

    def post(to:, message:, **kwrest, &block)
      current_world.send_direct_message(text: message, user: to, &block)
    end

    def postable?(user)
      user.class.slug == :twitter_user and current_world.class.slug == :twitter
    end

    private
    def current_world
      world, = Plugin.filtering(:world_current, nil)
      world
    end
  end

end
