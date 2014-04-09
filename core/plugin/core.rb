# -*- coding: utf-8 -*-

Plugin.create :core do

  # Serviceと、Messageの配列を受け取り、一度以上受け取ったことのあるものを除外して返すフィルタを作成して返す。
  # ただし、除外したかどうかはService毎に記録する。
  # また、アカウント登録前等、serviceがnilの時はシステムメッセージ以外を全て削除し、記録しない。
  # ==== Return
  # フィルタのプロシージャ(Proc)
  def gen_message_filter_with_service
    service_filters = Hash.new{|h,k|h[k] = gen_message_filter}
    ->(service, messages, &cancel) {
      if service
        [service] + service_filters[service.user_obj.id].(messages)
      else
        system = messages.select(&:system?)
        if system.empty?
          cancel.call
        else
          [nil, system] end end } end

  # Messageの配列を受け取り、一度以上受け取ったことのあるものを除外して返すフィルタを作成して返す
  # ==== Return
  # フィルタのプロシージャ(Proc)
  def gen_message_filter
    appeared = Set.new
    -> (messages){
      [messages.select{ |message|
         appeared.add(message.id) unless appeared.include?(message.id) }] } end

  filter_update(&gen_message_filter_with_service)

  filter_mention(&gen_message_filter_with_service)

  filter_appear(&gen_message_filter)

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

  Plugin.create(:core) do

    defevent :favorite,
    priority: :ui_favorited,
    prototype: [Service, User, Message]

    defevent :unfavorite,
    priority: :ui_favorited,
    prototype: [Service, User, Message]

    favorites = Hash.new{ |h, k| h[k] = Set.new } # {user_id: set(message_id)}
    unfavorites = Hash.new{ |h, k| h[k] = Set.new } # {user_id: set(message_id)}

    onappear do |messages|
      retweets = messages.select(&:retweet?)
      if not(retweets.empty?)
        Plugin.call(:retweet, retweets) end end

    on_boot do
      Event.filter_another_thread = true end

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
