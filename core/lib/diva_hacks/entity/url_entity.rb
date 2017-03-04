# -*- coding: utf-8 -*-

require_relative 'regexp_entity'

module Diva::Entity

=begin rdoc
schemeはhttpまたはhttpsのURLを全てリンクにするEntity。
==== Examples

   Diva::Entity::URLEntity.new(message)

=end
  URLEntity = Diva::Entity::RegexpEntity.filter(URI.regexp(%w<http https>),
                                                generator: ->s{ s.merge(open: s[:url]) })
end
