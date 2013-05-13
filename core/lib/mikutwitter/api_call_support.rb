# -*- coding: utf-8 -*-

require "mikutwitter/basic"
require "mikutwitter/query"
require "json"
require "timelimitedqueue"

module MikuTwitter::ApiCallSupport
  HTML_ATTR_UNESCAPE_HASH = {
    '&amp;' => '&',
    '&lt;' => '<',
    '&gt;' => '>',
    '&quot;' => '"' }.freeze

  include MikuTwitter::Query

  # APIのパスを指定する。
  # 例えば、 statuses/show/1234567890.json?include_entities=true を叩きたい場合は、以下のように書く。
  # (twitter/:statuses/:show/1234567890).json include_entities: true
  def /(api)
    Request.new(api, self) end

  class Request
    attr_reader :api, :twitter

    # このリクエストにOAuthを使用することを強制する。
    # OAuthなしでも使えるが、OAuthトークンを用いてリクエストした時に
    # 追加の情報が得られ、それが欲しい場合に使う
    attr_accessor :force_oauth

    # - 複数の同種のオブジェクトが配列で返ってくることを想定したパーサ
    # - オブジェクトが一つだけ返ってくることを想定したパーサ
    # - 同種のオブジェクトが大量に返ってくるが、cursorを使ってページが分かれているデータ用のパーサ
    # の3つを定義する。
    # メソッドの名前は上から順番に、 multi, uni, paged_#{multi} になる。
    # ==== Args
    # [uni] 名前（単数形）
    # [multi] 名前（複数形）
    def self.defparser(uni, multi = :"#{uni}s", container = Array, defaults = {})
      parser = lazy{ MikuTwitter::ApiCallSupport::Request::Parser.method(uni) }
      define_method(multi){ |options = {}|
        type_strict options => Hash
        json(defaults.merge(options)).next{ |node|
          Thread.new{ container.new(node.map(&parser)).freeze } } }

      define_method(uni){ |options = {}|
        type_strict options => Hash
        json(defaults.merge(options)).next{ |node|
          Thread.new{ parser.call(node) } } }

      define_method(:"paged_#{multi}"){ |options|
        type_strict options => Hash
        json(defaults.merge(options)).next{ |node = {}|
          Thread.new {
            node[multi] = node[multi].map(&parser)
            node } } } end

    def initialize(api, twitter)
      @api, @twitter, @force_oauth = api, twitter, false end

    def /(nex)
      result = Request.new("#{@api}/#{nex}", twitter)
      result.force_oauth = force_oauth
      result end

    # APIリクエストを実際に発行する
    # ==== Args
    # [options] API引数(Hash)
    # ==== Return
    # Deferredのインスタンス
    def json(options)
      type_strict options => Hash
      twitter.api(api, options, force_oauth).next{ |res|
        Thread.new{ JSON.parse(res.body).symbolize } } end

    defparser :user, :users, Users
    defparser :message, :messages, Messages
    defparser :list
    defparser :id
    defparser :direct_message

    def friendship(options = {})
      type_strict options => Hash
      json(options).next{ |res|
        relationship = res[:relationship]
        { following: relationship[:source][:following],     # 自分がフォローしているか
          followed_by: relationship[:source][:followed_by], # 相手にフォローされているか
          user: User.new_ifnecessary(idname: relationship[:target][:screen_name], # 相手
                                     id: relationship[:target][:id]) } } end

    def search(options = {})
      type_strict options => Hash
      json(options).next{ |res|
        Thread.new { Parser.messages res[:statuses] } } end

    def inspect
      "#<#{MikuTwitter::ApiCallSupport::Request}: #{@api}>"
    end

    module Parser
      extend Parser

      def message(msg)
        cnv = msg.convert_key(:text => :message,
                              :in_reply_to_user_id => :receiver,
                              :in_reply_to_status_id => :replyto)
        cnv[:source] = $1 if cnv[:source].is_a?(String) and cnv[:source].match(/^<a\s+.*>(.*?)<\/a>$/)
        cnv[:created] = (Time.parse(msg[:created_at]) rescue Time.now)
        cnv[:user] = Message::MessageUser.new(user(msg[:user]), msg[:user])
        cnv[:retweet] = message(msg[:retweeted_status]) if msg[:retweeted_status]
        cnv[:exact] = [:created_at, :source, :user, :retweeted_status].all?{|k|msg.has_key?(k)}
        message = cnv[:exact] ? Message.rewind(cnv) : Message.new_ifnecessary(cnv)
        message end

      def messages(msgs)
        Messages.new msgs.map{ |msg| message(msg) } end

      def user(u)
        cnv = u.convert_key(:screen_name =>:idname, :url => :url)
        cnv[:created] = Time.parse(u[:created_at])
        cnv[:detail] = u[:description]
        cnv[:protected] = !!u[:protected]
        cnv[:followers_count] = u[:followers_count].to_i
        cnv[:friends_count] = u[:friends_count].to_i
        cnv[:statuses_count] = u[:statuses_count].to_i
        cnv[:notifications] = u[:notifications]
        cnv[:verified] = u[:verified]
        cnv[:following] = u[:following]
        cnv[:exact] = [:created_at, :description, :protected, :followers_count, :friends_count, :verified].all?{|k|u.has_key?(k)}
        cnv[:exact] ? User.rewind(cnv) : User.new_ifnecessary(cnv) end

      def list(list)
        cnv = list.dup
        cnv[:mode] = list[:mode] == 'public'
        cnv[:user] = user(list[:user])
        cnv[:exact] = true
        cnv[:exact] ? UserList.rewind(cnv) : UserList.new_ifnecessary(cnv)
      end

      def direct_message(dm)
        cnv = dm.dup
        cnv[:sender] = user(dm[:sender])
        cnv[:recipient] = user(dm[:recipient])
        cnv[:exact] = true
        cnv end

      def id(id)
        id end

    end

  end
end

class MikuTwitter; include MikuTwitter::ApiCallSupport end
