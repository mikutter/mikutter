# -*- coding: utf-8 -*-

require_relative "basic"
require 'addressable/uri'

module MikuTwitter::APIShortcuts

  RELATIONAL_DEFAULT = {count: 5000}.freeze

  def self.defshortcut(method_name, api, parser, key_convert = {}, defaults = {})
    if block_given?
      define_method(method_name, &yield(api, parser))
    else
      define_method(method_name){ |args = {}|
        args = args.to_hash
        key_convert.each{ |src, dst|
          args[dst] = args[src] if args.has_key?(src) }
        (self/api).__send__(parser, defaults.merge(args)) } end end

  def self.defcursorpager(method_name, api, parser, key, key_convert = {})
    define_method(method_name){ |args = {}|
      key_convert.each{ |src, dst|
        args[dst] = args[src] if args.has_key?(src) }
      cursor_pager(self/api, parser, key, args) } end

  #
  # = GET関連
  #

  defshortcut :user_timeline, 'statuses/user_timeline', :messages, id: :user_id

  defshortcut :friends_timeline, 'statuses/home_timeline', :messages
  alias home_timeline friends_timeline

  defshortcut :replies, 'statuses/mentions_timeline', :messages
  alias mentions replies

  defshortcut :favorites, 'favorites', :message

  defshortcut :search, 'search/tweets', :search

  defshortcut :trends, :trends, :json

  defshortcut :retweeted_to_me, "statuses/retweeted_to_me", :messages

  defshortcut :retweets_of_me, "statuses/retweets_of_me", :messages

  defshortcut :friendship, 'friendships/show', :friendship

  defcursorpager :friends_id, 'friends/ids', :paged_ids, :ids, id: :user_id

  defcursorpager :followers_id, 'followers/ids', :paged_ids, :ids, id: :user_id

  def followings(args = {})
    idlist2userlist(friends_id(RELATIONAL_DEFAULT.merge(args)), cache: args[:cache]) end

  def followers(args = {})
    idlist2userlist(followers_id(RELATIONAL_DEFAULT.merge(args)), cache: args[:cache]) end

  def direct_messages(args = {})
    (self/:direct_messages).direct_messages({:count => 200}.merge(args)) end

  def sent_direct_messages(args = {})
    (self/'direct_messages/sent').direct_messages({:count => 200}.merge(args)) end

  defshortcut :user_show, "users/show", :user, {id: :user_id}, cache: true

  defshortcut :user_lookup, "users/lookup", :users, {id: :user_id}, cache: true

  def status_show(args = {})
    (self/"statuses/show").message({cache: true}.merge(args)) end

  defshortcut :saved_searches, "saved_searches/list", :json

  defshortcut :search_create, "saved_searches/create", :json

  def search_destroy(args = {})
    id = args[:id]
    args = args.dup
    args.delete(:id)
    (self/"saved_searches/destroy"/id).json(args) end

  def lists(args = {})
    (self/'lists/list').lists(args) end

  def list_subscriptions(args = {})
    args[:user_id] = args[:user][:id] if args[:user]
    cursor_pager(self/'lists/subscriptions', :paged_lists, :lists, {count: 1000}.merge(args)) end

  def list_members(args = {})
    args[:list_id] = args[:id] if args[:id]
    request = self/'lists/members'
    request.force_oauth = !args[:public]
    cursor_pager(request, :paged_users, :users, args) end

  def list_user_followers(args = {})
    args[:user_id] = args[:id] if args[:id]
    request = self/'lists/memberships'
    request.force_oauth = args[:filter_to_owned_lists] || !args[:public]
    cursor_pager(request, :paged_lists, :lists, args) end

  def list_statuses(args = {})
    args[:list_id] = args[:id] if args[:id]
    request = self/"lists/statuses"
    request.force_oauth = !args[:public]
    request.messages(args)
  end

  def retweeted_users(args = {})
    args[:id] = args[:status_id] if args[:status_id]
    request = self/:statuses/:retweeters/:ids
    cursor_pager(request, :paged_ids, :ids, args).next do |ids|
      Thread.new{ Plugin::Twitter::User.findbyid(ids) }
    end
  end

  defshortcut :rate_limit_status, "account/rate_limit_status", :json

  defshortcut :verify_credentials, "account/verify_credentials", :user

  #
  # = POST関連
  #

  def update(message)
    text = message[:message]
    replyto = message[:replyto] && Plugin::Twitter::Message.generate(message[:replyto])
    receiver = message[:receiver] && Plugin::Twitter::User.generate(message[:receiver])
    iolist = message[:mediaiolist]
    is_reply = !!(receiver || replyto)
    data = {:status => text }
    data[:in_reply_to_user_id] = receiver.id if receiver
    data[:in_reply_to_status_id] = replyto.id if replyto
    if is_reply && UserConfig[:auto_populate_reply_metadata]
      data[:auto_populate_reply_metadata] = true
      forecast_receivers = Set.new
      exclude_receivers = Set.new
      if replyto
        replyto.each_ancestor.each do |m|
          forecast_receivers << m.user
          forecast_receivers.merge(m.receive_user_screen_names.map{|sn| Plugin::Twitter::User.findbyidname(sn) }.compact)
        end
      end
      mentions = text.match(%r[\A((?:@[a-zA-Z0-9_]+\s+)+)])
      if mentions
        specific_screen_names = mentions[1].split(/\s+/).map{|s|s[1, s.size]}
        exclude_receivers += forecast_receivers.reject{|u| specific_screen_names.include?(u.idname) }
        text = [*(specific_screen_names - forecast_receivers.map(&:idname)).map{|s|"@#{s}"}, text[mentions.end(0),text.size]].join(' '.freeze)
        data[:status] = text
      end
      data[:exclude_reply_user_ids] = exclude_receivers.map(&:id).join(',') unless exclude_receivers.empty?
    end
    if iolist and !iolist.empty?
      Deferred.when(*iolist.collect{ |io| upload_media(io) }).next{|media_list|
        data[:media_ids] = media_list.map{|media| media['media_id'] }.join(",")
        (self/'statuses/update').message(data) }
    else
      attachment_url = text.match(%r[\A(.+?)\s+(https?://twitter.com/(?:#!/)?(?:[a-zA-Z0-9_]+)/status(?:es)?/(?:\d+)(?:\?.*)?)\Z]m)
      if attachment_url
        data[:attachment_url] = attachment_url[2]
        data[:status] = attachment_url[1]
      end
      (self/'statuses/update').message(data) end end
  alias post update

  def retweet(args = {})
    id = args[:id]
    (self/"statuses/retweet"/id).message end

  def destroy(args)
    id = args[:id]
    (self/"statuses/destroy"/id).message end

  defshortcut :send_direct_message, "direct_messages/new", :direct_message

  defshortcut :destroy_direct_message, "direct_messages/destroy", :direct_message

  defshortcut :favorite, "favorites/create", :message

  defshortcut :unfavorite, "favorites/destroy", :message

  defshortcut :follow, "friendships/create", :user, id: :user_id

  defshortcut :unfollow, "friendships/destroy", :user, id: :user_id

  # list = {
  #   :user => User(自分)
  #   :name => String
  #   :description => String
  #   :public => boolean
  # }
  def add_list(list)
    (self/"lists/create").list( name: list[:name].to_s[0, 25],
                                        description: list[:description].to_s[0, 100],
                                        mode: (list[:mode] ? 'public' : 'private')) end

  def update_list(list)
    (self/"lists/update").list( list_id: list[:id],
                                name: list[:name].to_s[0, 25],
                                description: list[:description].to_s[0, 100],
                                mode: (list[:mode] ? 'public' : 'private')) end

  defshortcut :delete_list, "lists/destroy", :list, id: :list_id

  defshortcut :add_list_member, "lists/members/create", :list

  defshortcut :delete_list_member, "lists/members/destroy", :list

  #
  # Streaming API関連
  #

  def userstream(params={}, &chunk)
    stream("https://userstream.twitter.com/1.1/user.json", params, &chunk) end

  def filter_stream(params={}, &chunk)
    stream("https://stream.twitter.com/1.1/statuses/filter.json", params, &chunk) end

  private

  # Streaming APIに接続して、_chunk_ に流れてきたデータを一つづつ文字列で渡して呼び出す
  # ==== Args
  # [url] 接続するURL
  # [params] POSTパラメータ
  # [&chunk] データを受け取るコールバック
  def stream(url, params, &chunk)
    parsed_url = Addressable::URI.parse(url)
    stream_access_token = access_token("#{parsed_url.scheme}://#{parsed_url.host}")
    http = stream_access_token.consumer.http
    http.read_timeout = 90
    consumer = stream_access_token.consumer
    request = consumer.create_signed_request(:post,
                                             parsed_url.path,
                                             stream_access_token,
                                             {},
                                             params,
                                             { 'Host' => parsed_url.host,
                                               'User-Agent' => "#{Environment::NAME}/#{Environment::VERSION}",
                                               'accept-encoding' => "identity;q=1"})
    proc = line_accumlator("\x0D\x0A", &chunk)
    http.request(request){ |res|
      if res.code == '200'
        res.read_body(&proc)
      end } end

  # APIの戻り値に、 next_cursor とかがついてて、二ページ目以降の取得がやたら面倒な
  # APIを、全部まとめて取得する。
  # ==== Args
  # [api] APIオブジェクト(self/:statuses/:show とか)
  # [parser] パーサメソッドの名前(:json とか)
  # [key] 内容の配列のキー
  # [args] API引数
  # ==== Return
  # Deferred (nextの引数に、全ページの結果をすべて連結した配列)
  def cursor_pager(api, parser, key, args)
    api.__send__(parser, args).next{ |res|
      if res[:next_cursor] == 0
        res[key]
      else
        cursor_pager(api, parser, key, args.merge(cursor: res[:next_cursor])).next{ |nex|
          res[key] + nex } end } end

  def idlist2userlist(deferred, cache: :keep)
    deferred.next do |ids|
      detected = {}           # {id => User}
      lookups = Set.new       # [id]
      ids.each do |id|
        user = Plugin::Twitter::User.findbyid(id, Diva::DataSource::USE_LOCAL_ONLY)
        if user.is_a? Plugin::Twitter::User
          detected[id] = user
        else
          lookups << id
        end
      end
      defer = lookups.each_slice(100).map{|lookup_chunk|
        user_lookup(id: lookup_chunk.join(','), cache: cache).next{|users|
          users.each do |user|
            detected[user.id] = user
          end
        }
      }
      Delayer::Deferred.when(*defer).next do
        ids.map{|id| detected[id] }
      end
    end
  end

  # upload.twitter.comに画像等をアップロードし、
  # アップロードしたファイルのmedia_idを返す。
  # ==== Args
  # [io] アップロードする画像ファイルのIO
  # ==== Return
  # Deferred
  def upload_media(io)
    api('media/upload',
        host: 'upload.twitter.com/1.1',
        media: Base64.encode64(io.read)).next{|res|
      JSON.parse(res.body)
    }
  end
end

class MikuTwitter; include MikuTwitter::APIShortcuts end
