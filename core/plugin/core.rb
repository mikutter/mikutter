# -*- coding: utf-8 -*-

Plugin.create :core do

  # appearイベントには二回以上同じMessageを渡さない
  @appear_fired = Set.new
  filter_appear do |messages|
    [ messages.select{ |m|
        if not @appear_fired.include?(m[:id])
          @appear_fired << m[:id] end } ] end

  # リツイートを削除した時、ちゃんとリツイートリストからそれを削除する
  on_destroyed do |messages|
    messages.each{ |message|
      if message.retweet?
        source = message.retweet_source(false)
        if source
          notice "retweet #{source[:id]} #{message.to_s}(##{message[:id]})"
          Plugin.call(:retweet_destroyed, source, message.user, message[:id])
          source.retweeted_statuses.delete(message) end end } end

  on_entity_linkrule_added(&Message::Entity.method(:on_entity_linkrule_added))

end

Module.new do
  def self.gen_never_message_filter
    appeared = Set.new
    lambda{ |service, messages|
      [service,
       messages.select{ |m|
         appeared.add(m[:id].to_i) if m and not(appeared.include?(m[:id].to_i)) }] } end

  def self.never_message_filter(event_name, &filter_func)
    Plugin.create(:core).add_event_filter(event_name, &(filter_func || gen_never_message_filter))
  end

  never_message_filter :update
  never_message_filter :mention
  appeared = Set.new
  never_message_filter(:appear){ |messages|
    [messages.select{ |m|
       appeared.add(m[:id].to_i) if m and not(appeared.include?(m[:id].to_i)) }] }

  Plugin.create(:core) do
    favorites = Hash.new{ |h, k| h[k] = Set.new } # {user_id: set(message_id)}
    unfavorites = Hash.new{ |h, k| h[k] = Set.new } # {user_id: set(message_id)}

    onappear do |messages|
      retweets = messages.select(&:retweet?)
      if not(retweets.empty?)
        Plugin.call(:retweet, retweets) end end

    # 同じツイートに対するfavoriteイベントは一度しか発生させない
    filter_favorite do |service, user, message|
      Plugin.filter_cancel! if favorites[user[:id]].include? message[:id]
      favorites[user[:id]] << message[:id]
      [service, user, message]
    end

    # 同じツイートに対するunfavoriteイベントは一度しか発生させない
    filter_unfavorite do |service, user, message|
      Plugin.filter_cancel! if unfavorites[user[:id]].include? message[:id]
      unfavorites[user[:id]] << message[:id]
      [service, user, message]
    end

    # followers_createdイベントが発生したら、followイベントも発生させる
    on_followers_created do |service, users|
      users.each{ |user|
        Plugin.call(:follow, user, service.user_obj) } end

    # followings_createdイベントが発生したら、followイベントも発生させる
    on_followings_created do |service, users|
      users.each{ |user|
        Plugin.call(:follow, service.user_obj, user) } end

  end

end
