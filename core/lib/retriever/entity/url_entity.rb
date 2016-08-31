# -*- coding: utf-8 -*-

require_relative 'regexp_entity'

module Retriever::Entity

=begin rdoc
schemeはhttpまたはhttpsのURLを全てリンクにするEntity。
==== Examples

   Retriever::Entity::URLEntity.new(message)

=end
  URLEntity = Retriever::Entity::RegexpEntity.filter(URI.regexp(%w<http https>),
                                                     generator: ret_nth,
                                                     open: ->s{ Gtk::TimeLine.openurl(s[:url]) })
end
