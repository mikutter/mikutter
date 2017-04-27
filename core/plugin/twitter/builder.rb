# -*- coding: utf-8 -*-
require_relative 'model/world'

module Plugin::Twitter
  class Builder
    def initialize(consumer_key, consumer_secret)
      super()
      @twitter = MikuTwitter.new
      @twitter.consumer_key = consumer_key
      @twitter.consumer_secret = consumer_secret
    end

    def request_token
      @request_token ||= @twitter.request_oauth_token
    end

    def authorize_url
      request_token.authorize_url
    end

    def build(verifier)
      verify(verifier)
    end

    private

    def verify(verifier)
      Thread.new{
        access_token = request_token.get_access_token(oauth_token: request_token.token,
                                                      oauth_verifier: verifier)
        @twitter.a_token = access_token.token
        @twitter.a_secret = access_token.secret
        (@twitter/:account/:verify_credentials).user
      }.next{|user|
        Plugin::Twitter::World.new(
          id: "twitter#{user.id}",
          slug: "twitter#{user.id}",
          token: @twitter.a_token,
          secret: @twitter.a_secret,
          user: user)
      }
    end
  end
end
