# -*- coding: utf-8 -*-

require "mikutwitter/basic"
module MikuTwitter::APIShortcuts

  def self.defshortcut(method_name, api, parser, key_convert = {}, defaults = {})
    if block_given?
      define_method(method_name, &yield(api, parser))
    else
      define_method(method_name){ |args = {}|
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

  defshortcut :replies, 'statuses/mentions', :messages
  alias mentions replies

  defshortcut :favorites, 'favorites', :message

  def search(args = {})
    (self/:search).search({host: 'search.twitter.com'}.merge(args)) end

  defshortcut :trends, :trends, :json

  defshortcut :retweeted_to_me, "statuses/retweeted_to_me", :messages

  defshortcut :retweets_of_me, "statuses/retweets_of_me", :messages

  defshortcut :friendship, 'friendships/show', :friendship

  defcursorpager :friends_id, 'friends/ids', :paged_ids, :ids, id: :user_id

  defcursorpager :followers_id, 'followers/ids', :paged_ids, :ids, id: :user_id

  def followings(args = {})
    idlist2userlist(friends_id(args)) end

  def followers(args = {})
    idlist2userlist(followers_id(args)) end

  def direct_messages(args = {})
    (self/:direct_messages).direct_messages({:count => 200}.merge(args)) end

  def sent_direct_messages(args = {})
    (self/'direct_messages/sent').direct_messages({:count => 200}.merge(args)) end

  defshortcut :user_show, "users/show", :user, {id: :user_id}, cache: true

  defshortcut :user_lookup, "users/lookup", :users, {id: :user_id}, cache: true

  def status_show(args = {})
    (self/"statuses/show").message({cache: true}.merge(args)) end

  defshortcut :saved_searches, :saved_searches, :json

  defshortcut :search_create, "saved_searches/create", :json

  def search_destroy(args = {})
    id = args[:id]
    args = args.dup
    args.delete(:id)
    (self/"saved_searches/destroy"/id).json(args) end

  def lists(args = {})
    (self/'lists/all').lists(args) end

  def list_subscriptions(args = {})
    args[:user_id] = args[:user][:id] if args[:user]
    cursor_pager(self/'lists/subscriptions', :paged_lists, :lists, {count: 1000}.merge(args)) end

  def list_members(args=nil)
    args[:list_id] = args[:id] if args[:id]
    cursor_pager(self/'lists/members', :paged_users, :users, args) end

  def list_user_followers(args=nil)
    args[:user_id] = args[:id] if args[:id]
    request = self/'lists/memberships'
    request.force_oauth = true if(args[:filter_to_owned_lists])
    cursor_pager(request, :paged_lists, :lists, args) end

  defshortcut :list_statuses, "lists/statuses", :messages, id: :list_id

  defshortcut :rate_limit_status, "account/rate_limit_status", :json

  defshortcut :verify_credentials, "account/verify_credentials", :user

  #
  # = POST関連
  #

  def update(message)
    text = message[:message]
    replyto = message[:replyto]
    receiver = message[:receiver]
    data = {:status => text }
    data[:in_reply_to_user_id] = User.generate(receiver)[:id].to_s if receiver
    data[:in_reply_to_status_id] = Message.generate(replyto)[:id].to_s if replyto
    (self/'statuses/update').message(data) end
  alias post update

  def retweet(args = {})
    id = args[:id]
    (self/"statuses/retweet"/id).message end

  def destroy(args)
    id = args[:id]
    (self/"statuses/destroy"/id).message end

  def send_direct_message(args = {})
    (self/"direct_messages/new").direct_message(args)
  end

  def destroy_direct_message(args)
    id = args[:id]
    args = args.dup
    args.delete(:id)
    (self/"direct_messages/destroy"/id).direct_message(args)
  end

  def favorite(args = {})
    id = args[:id]
    (self/"favorites/create"/id).message end

  def unfavorite(args = {})
    id = args[:id]
    (self/"favorites/destroy"/id).message end

  def follow(user)
    user_id = user[:id]
    if user.is_a? Hash
      args = user.dup
      args.delete(:id)
    else
      args = {} end
    (self/"friendships/create"/user_id).user(args)
  end

  def unfollow(user)
    user_id = user[:id]
    if user.is_a? Hash
      args = user.dup
      args.delete(:id)
    else
      args = {} end
    (self/"friendships/destroy"/user_id).user(args)
  end

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

  def userstream
    begin
      access_token.get('https://userstream.twitter.com/2/user.json',
                       'Host' => 'userstream.twitter.com',
                       'User-Agent' => "#{Environment::NAME}/#{Environment::VERSION}"){ |res|
        res.read_body(&Proc.new) }
    rescue Exception => evar
      warn evar end end

  def filter_stream(params={})
    begin
      callback = Proc.new
      buf = ""
      access_token.post('https://stream.twitter.com/1/statuses/filter.json',
                        params,
                        'Host' => 'stream.twitter.com',
                        'User-Agent' => "#{Environment::NAME}/#{Environment::VERSION}"){ |res|
        res.read_body{ |chunk|
          if chunk[-1] == "\n"
            callback.call(buf + chunk)
            buf.clear
          else
            buf << chunk end } }
    rescue Exception => evar
      warn evar end end

  private

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
    require_if_exist 'pry'
    api.__send__(parser, args).next{ |res|
      if res[:next_cursor] == 0
        res[key]
      else
        cursor_pager(api, parser, key, args.merge(cursor: res[:next_cursor])).next{ |nex|
          res[key] + nex } end } end

  def idlist2userlist(promise)
    promise.next{ |ids|
      promise = Deferred.new(true)
      Thread.new{
        begin
          promise.call(User.findbyid(ids))
        rescue Exception => e
          promise.fail(e) end }
      promise.next{ |users|
        if(users.size != ids.size)
          Deferred.when(*(ids - users.map{ |u| u[:id] }).each_slice(100).map{ |segment|
                          user_lookup(id: segment.join(',')).trap{ |e| warn e; [] } }).next{ |res|
            res.inject(users){ |a, b| a + b } }
        else
          users end } } end

end

class MikuTwitter; include MikuTwitter::APIShortcuts end

