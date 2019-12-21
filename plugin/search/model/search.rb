# -*- coding: utf-8 -*-

module Plugin::Search
  class Search < Diva::Model
    extend Memoist
    register :search_search, name: Plugin[:search]._('検索')

    field.string :query, required: true
    field.has :world, Diva::Model, required: true

    handle ->uri {
      uri.scheme == 'search' && find_world(uri) && uri.path.size >= 2
    } do |uri|
      host = CGI.unescape(uri.host)
      new(query: CGI.unescape(uri.path), world: find_world(uri))
    end

    def self.find_world(uri)
      Enumerator.new { |y|
        Plugin.filtering(:worlds, y)
      }.lazy.map { |w|
        w.slug.to_s
      }.find(CGI.unescape(uri.host))
    end

    def title
      Plugin[:search]._("「%{query}」を%{world}で検索") % {query: query, world: world.title}
    end

    def uri
      Diva::URI.new("search://#{CGI.escape(self.world.slug.to_s)}/#{CGI.escape(self.query)}")
    end
  end
end
