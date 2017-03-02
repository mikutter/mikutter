# -*- coding: utf-8 -*-
require_relative 'basic_twitter_entity'

module Diva::Entity
  ExtendedTwitterEntity = BasicTwitterEntity.filter(
    Diva::Entity::BasicTwitterEntity::MentionMatcher, generator: ->h{
      sn = Diva::Entity::BasicTwitterEntity::MentionExactMatcher.match(h[:url])[1]
      user = Diva::Model(:twitter_user)
      if user
        h[:open] = user.findbyidname(sn, Diva::DataSource::USE_LOCAL_ONLY) ||
                        Diva::URI.new("https://twitter.com/#{sn}")
      else
        h[:open] = Diva::URI.new("https://twitter.com/#{sn}")
      end
      h
    }).filter(
    URI.regexp(%w[http https]), generator: ->h{
      h.merge(open: h[:url])
    }).filter(
    /(?:#|＃)[a-zA-Z0-9_]+/, generator: ->h{
      twitter_search = Diva::Model(:twitter_search)
      if twitter_search
        h[:open] = twitter_search.new(query: "##{h[:url][1..h[:url].size]}") end
      h
    })

end
