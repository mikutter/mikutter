Plugin.create :twitter_search do
  intent :twitter_hashtag do |token|
    Plugin.call(:search_start, token.model.title)
  end
end
