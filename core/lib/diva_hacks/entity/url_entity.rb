# -*- coding: utf-8 -*-

require_relative 'regexp_entity'

module Retriever::Entity

=begin rdoc
schemeはhttpまたはhttpsのURLを全てリンクにするEntity。
==== Examples

   Retriever::Entity::URLEntity.new(message)

=end
  URLEntity = Retriever::Entity::RegexpEntity.filter(URI.regexp(%w<http https>),
                                                     generator: ->s{ s.merge(open: s[:url]) })
end
