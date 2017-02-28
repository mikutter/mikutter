# -*- coding: utf-8 -*-
require_relative 'basic_twitter_entity'

module Retriever::Entity
  ExtendedTwitterEntity = BasicTwitterEntity.filter(
    Retriever::Entity::BasicTwitterEntity::MentionMatcher, generator: ->h{
      sn = Retriever::Entity::BasicTwitterEntity::MentionExactMatcher.match(h[:url])[1]
      user = Retriever::Model(:twitter_user)
      if user
        h[:open] = user.findbyidname(sn, Retriever::DataSource::USE_LOCAL_ONLY) ||
                        Retriever::URI.new("https://twitter.com/#{sn}")
      else
        h[:open] = Retriever::URI.new("https://twitter.com/#{sn}")
      end
      h
    }).filter(
    URI.regexp(%w[http https]), generator: ->h{
      h.merge(open: h[:url])
    }).filter(
    /(?:#|＃)[a-zA-Z0-9_]+/, generator: ->h{
      twitter_search = Retriever::Model(:twitter_search)
      if twitter_search
        h[:open] = twitter_search.new(query: "##{h[:url][1..h[:url].size]}") end
      h
    })

end
