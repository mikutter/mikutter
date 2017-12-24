# -*- coding: utf-8 -*-
require 'json'

module Plugin::Twitter; end

require_relative 'builder'
require_relative 'model'
require_relative 'mikutwitter'

Plugin.create(:twitter) do

  defevent :favorite,
           priority: :ui_favorited,
           prototype: [Diva::Model, Plugin::Twitter::User, Plugin::Twitter::Message]

  defevent :unfavorite,
           priority: :ui_favorited,
           prototype: [Diva::Model, Plugin::Twitter::User, Plugin::Twitter::Message]

  favorites = Hash.new{ |h, k| h[k] = Set.new } # {user_id: set(message_id)}
  unfavorites = Hash.new{ |h, k| h[k] = Set.new } # {user_id: set(message_id)}

  @twitter_configuration = JSON.parse(file_get_contents(File.join(__dir__, 'configuration.json'.freeze)), symbolize_names: true)

  # Twitter API help/configuration.json を叩いて最新情報を取得する
  Delayer.new do
    twitter = Enumerator.new{|y|
      Plugin.filtering(:worlds, y)
    }.find{|world|
      world.class.slug == :twitter
    }
    if twitter
      (twitter/:help/:configuration).json(cache: true).next do |configuration|
        @twitter_configuration = configuration.symbolize
      end
    end
  end

  # Serviceと、Messageの配列を受け取り、一度以上受け取ったことのあるものを除外して返すフィルタを作成して返す。
  # ただし、除外したかどうかはService毎に記録する。
  # また、アカウント登録前等、serviceがnilの時はシステムメッセージ以外を全て削除し、記録しない。
  # ==== Return
  # フィルタのプロシージャ(Proc)
  def gen_message_filter_with_service
    service_filters = Hash.new{|h,k|h[k] = gen_message_filter}
    ->(service, messages, &cancel) do
      if service
        [service] + service_filters[service.user_obj.id].(messages)
      else
        system = messages.select(&:system?)
        if system.empty?
          cancel.call
        else
          [nil, system]
        end
      end
    end
  end

  # Messageの配列を受け取り、一度以上受け取ったことのあるものを除外して返すフィルタを作成して返す
  # ==== Return
  # フィルタのプロシージャ(Proc)
  def gen_message_filter
    appeared = Set.new
    ->(messages) do
      [messages.select{ |message| appeared.add(message.id) unless appeared.include?(message.id) }]
    end
  end

  # URL _url_ がTwitterに投稿された時に何文字としてカウントされるかを返す
  # ==== Args
  # [url] String URL
  # ==== Return
  # Fixnum URLの長さ
  def posted_url_length(url)
    if url.start_with?('https://'.freeze)
      @twitter_configuration[:short_url_length_https] || 23
    else
      @twitter_configuration[:short_url_length] || 22
    end
  end

  filter_update(&gen_message_filter_with_service)

  filter_mention(&gen_message_filter_with_service)

  filter_direct_messages(&gen_message_filter_with_service)

  filter_appear(&gen_message_filter)

  defspell(:destroy, :twitter, :twitter_tweet,
           condition: ->(twitter, tweet){ tweet.from_me?(twitter) }
          ) do |twitter, tweet|
    (twitter/"statuses/destroy".freeze/tweet.id).message.next{ |destroyed_tweet|
      destroyed_tweet[:rule] = :destroy
      Plugin.call(:destroyed, [destroyed_tweet])
      destroyed_tweet
    }
  end

  defspell(:destroy_share, :twitter, :twitter_tweet,
           condition: ->(twitter, tweet){ shared?(twitter, tweet) }
          ) do |twitter, tweet|
    shared(twitter, tweet).next{ |retweet|
      destroy(twitter, retweet)
    }
  end

  defspell(:favorite, :twitter, :twitter_tweet,
           condition: ->(twitter, tweet){
             !favorited?(twitter, tweet)
           }) do |twitter, tweet|
    Plugin.call(:before_favorite, twitter, twitter.user_obj, tweet)
    (twitter/'favorites/create'.freeze).message(id: tweet.id).next{ |favorited_tweet|
      Plugin.call(:favorite, twitter, twitter.user_obj, favorited_tweet)
      favorited_tweet
    }.trap{ |e|
      Plugin.call(:fail_favorite, twitter, twitter.user_obj, tweet)
      Deferred.fail(e)
    }
  end

  defspell(:favorited, :twitter, :twitter_tweet,
           condition: ->(twitter, tweet){ favorited?(twitter.user_obj, tweet) }
          ) do |twitter, tweet|
    Delayer::Deferred.new.next{
      favorited?(twitter.user, tweet)
    }
  end

  defspell(:favorited, :twitter_user, :twitter_tweet,
           condition: ->(user, tweet){ tweet.favorited_by.include?(user) }
          ) do |user, tweet|
    Delayer::Deferred.new.next{
      favorited?(user, tweet)
    }
  end

  defspell(:compose, :twitter, :twitter_tweet,
           condition: ->(twitter, tweet, visibility: nil){
             !(visibility && visibility != :public)
           }) do |twitter, tweet, body:, **options|
    twitter.post_tweet(message: body, replyto: tweet, **options)
  end

  defspell(:compose, :twitter, :twitter_direct_message,
           condition: ->(twitter, direct_message, visibility: nil){
             !(visibility && visibility != :direct)
           }) do |twitter, direct_message, body:, **options|
    twitter.post_dm(user: direct_message.user, text: body, **options)
  end

  defspell(:compose, :twitter, :twitter_user,
           condition: ->(twitter, user, visibility: nil){
             !(visibility && ![:public, :direct].include?(visibility))
           }) do |twitter, user, visibility: nil, body:, **options|
    case visibility
    when :public, nil
      twitter.post_tweet(message: body, receiver: user, **options)
    when :direct
      twitter.post_dm(user: user, text: body, **options)
    else
      raise "invalid visibility `#{visibility.inspect}'."
    end
  end

  # 宛先なしのタイムラインへのツイートか、 _to_ オプション引数で複数宛てにする場合。
  # Twitterでは複数宛先は対応していないため、 _to_ オプションの1つめの値に対する投稿とする
  defspell(:compose, :twitter,
           condition: ->(twitter, to: nil){
             first = Array(to).compact.first
             !(first && !compose?(twitter, first))
           }) do |twitter, body:, to: nil, **options|
    first = Array(to).compact.first
    if first
      compose(twitter, first, body: body, **options)
    else
      twitter.post_tweet(to: to, message: body, **options)
    end
  end

  defspell(:share, :twitter, :twitter_tweet,
           condition: ->(twitter, tweet){ !tweet.protected? }
          ) do |twitter, tweet|
    twitter.retweet(id: tweet.id).next{|retweeted|
      Plugin.call(:posted, twitter, [retweeted])
      Plugin.call(:update, twitter, [retweeted])
      retweeted
    }
  end

  defspell(:shared, :twitter, :twitter_tweet,
           condition: ->(twitter, tweet){ tweet.retweeted_users.include?(twitter.user_obj) }
          ) do |twitter, tweet|
    Delayer::Deferred.new.next{
      retweet = tweet.retweeted_statuses.find{|rt| rt.user == twitter.user_obj }
      if retweet
        retweet
      else
        raise "ReTweet not found."
      end
    }
  end

  defspell(:unfavorite, :twitter, :twitter_tweet,
           condition: ->(twitter, tweet){
             favorited?(twitter, tweet)
           }) do |twitter, tweet|
    (twitter/'favorites/destroy'.freeze).message(id: tweet.id).next{ |unfavorited_tweet|
      Plugin.call(:unfavorite, twitter, twitter.user_obj, unfavorited_tweet)
      unfavorited_tweet
    }
  end

  defspell(:search, :twitter) do |twitter, **options|
    twitter.search(**options)
  end

  # リツイートを削除した時、ちゃんとリツイートリストからそれを削除する
  on_destroyed do |messages|
    messages.each{ |message|
      if message.retweet?
        source = message.retweet_source(false)
        if source
          Plugin.call(:retweet_destroyed, source, message.user, message[:id])
          source.retweeted_sources.delete(message) end end } end

  onappear do |messages|
    retweets = messages.select(&:retweet?).map do |message|
      result = message.retweet_ancestors.to_a[-2]
      fail "invalid retweet #{message.inspect}. ancestors: #{message.retweet_ancestors.to_a.inspect}" unless result.is_a?(Plugin::Twitter::Message)
      result
    end
    if not retweets.empty?
      Plugin.call(:retweet, retweets)
    end
  end

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
    users.each do |user|
      Plugin.call(:follow, user, service.user_obj)
    end
  end

  # followings_createdイベントが発生したら、followイベントも発生させる
  on_followings_created do |service, users|
    users.each do |user|
      Plugin.call(:follow, service.user_obj, user)
    end
  end

  # t.coによって短縮されたURLの長さを求める
  filter_tco_url_length do |url, length|
    [url, posted_url_length(url)]
  end

  # トークン切れの警告
  MikuTwitter::AuthenticationFailedAction.register do |service, method = nil, url = nil, options = nil, res = nil|
    activity(:system, _("アカウントエラー (@{user})", user: service.user),
             description: _("ユーザ @{user} のOAuth 認証が失敗しました (@{response})\n設定から、認証をやり直してください。",
                            user: service.user, response: res))
    nil
  end

  world_setting(:twitter, _('Twitter')) do
    builder = Plugin::Twitter::Builder.new(
      Environment::TWITTER_CONSUMER_KEY,
      Environment::TWITTER_CONSUMER_SECRET)
    label _("Webページにアクセスして表示された番号を、「トークン」に入力して、次へボタンを押してください。")
    link builder.authorize_url
    input "トークン", :token
    result = await_input

    world = await builder.build(result[:token])
    label _("このアカウントでログインしますか？")
    link world.user_obj
    world
  end
end
