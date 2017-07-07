# -*- coding: utf-8 -*-

module Plugin::Search
  class Search < Retriever::Model
    extend Memoist

    register :twitter_search, name: Plugin[:search]._('Twitter検索')

    field.string :query, required: true

    # https://twitter.com/search?q=%23superfuckjp
    handle ->uri{
      uri.scheme == 'https' &&
        uri.host == 'twitter.com' &&
        uri.path == '/search' &&
        uri.query.split('&').any?{|r|r.split('=', 2).first == 'q'}
    } do |uri|
      _, query = uri.query.split('&').lazy.map{|r| r.split('=', 2) }.find{|k,v| k == 'q' }
      new(query: CGI.unescape(query))
    end

    def title
      Plugin[:search]._("「%{query}」でツイート検索") % {query: query}
    end

    memoize def perma_link
      Retriever::URI.new("https://twitter.com/search?q=#{CGI.escape(self.query)}")
    end
  end
end
