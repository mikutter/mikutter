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

end
