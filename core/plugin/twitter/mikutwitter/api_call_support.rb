# -*- coding: utf-8 -*-

require_relative "basic"
require_relative "query"
require "json"
require "lib/timelimitedqueue"

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
    def self.defparser(uni, multi = :"#{uni}s", defaults = {})
      parser = lazy{ MikuTwitter::ApiCallSupport::Request::Parser.method(uni) }
      defaults.freeze
      define_method(multi){ |options = {}|
        type_strict options => Hash
        json(defaults.merge(options)).next{ |node|
          Thread.new{ node.map(&parser).freeze } } }

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

    defparser :user, :users
    defparser :message, :messages, tweet_mode: 'extended'.freeze
    defparser :list
    defparser :id
    defparser :direct_message

    def friendship(options = {})
      type_strict options => Hash
      json(options).next{ |res|
        relationship = res[:relationship]
        { following: relationship[:source][:following],     # 自分がフォローしているか
          followed_by: relationship[:source][:followed_by], # 相手にフォローされているか
          user: Plugin::Twitter::User.new_ifnecessary(idname: relationship[:target][:screen_name], # 相手
                                                      id: relationship[:target][:id]) } } end

    def search(options = {})
      type_strict options => Hash
      json({tweet_mode: 'extended'.freeze}.merge(options)).next{ |res|
        Thread.new { Parser.messages res[:statuses] } } end

    def inspect
      "#<#{MikuTwitter::ApiCallSupport::Request}: #{@api}>"
    end

    module Parser
      extend Parser

      def message(msg)
        cnv = msg.dup
        cnv[:message] = msg[:full_text] || msg[:text]
        cnv[:source] = $1 if cnv[:source].is_a?(String) and cnv[:source].match(/\A<a\s+.*>(.*?)<\/a>\Z/)
        cnv[:created] = (Time.parse(msg[:created_at]).localtime rescue Time.now)
        cnv[:user] = user(msg[:user])
        cnv[:retweet] = message(msg[:retweeted_status]) if msg[:retweeted_status]
        cnv[:exact] = [:created_at, :source, :user, :retweeted_status].all?{|k|msg.has_key?(k)}
        message = cnv[:exact] ? Plugin::Twitter::Message.rewind(cnv) : Plugin::Twitter::Message.new_ifnecessary(cnv)
        # search/tweets.json の戻り値のquoted_statusのuserがたまにnullだゾ〜
        if msg[:quoted_status].is_a?(Hash) and msg[:quoted_status][:user]
          message(msg[:quoted_status]).add_quoted_by(message) end
        message end

      # Streaming APIにはtweet_modeスイッチが効かないとかTwitterアホか！？
      # ↓
      # Parser#message に、compat modeも受け付けるような改修を入れる
      # ↓
      # Twitter「Streaming APIのcompatモードはちょっと中身が違うんじゃ」
      # see: https://dev.twitter.com/overview/api/upcoming-changes-to-tweets
      # ↓
      # 死にたいのか！？
      # ↓
      # つついさん「行けたけど」
      # see: https://dev.mikutter.hachune.net/issues/1206
      # ↓
      # 死んでいる
      # see: https://twitter.com/toshi_a
      def streaming_message(msg)
        cnv = msg.dup
        if msg[:extended_tweet]
          cnv.delete(:extended_tweet)
          cnv.merge!(msg[:extended_tweet])
          cnv[:message] = msg[:extended_tweet][:full_text]
        else
          cnv[:message] = msg[:text]
        end
        cnv[:source] = $1 if cnv[:source].is_a?(String) and cnv[:source].match(/\A<a\s+.*>(.*?)<\/a>\Z/)
        cnv[:created] = (Time.parse(msg[:created_at]).localtime rescue Time.now)
        cnv[:user] = user(msg[:user])
        cnv[:retweet] = streaming_message(msg[:retweeted_status]) if msg[:retweeted_status]
        cnv[:exact] = [:created_at, :source, :user, :retweeted_status].all?{|k|msg.has_key?(k)}
        message = cnv[:exact] ? Plugin::Twitter::Message.rewind(cnv) : Plugin::Twitter::Message.new_ifnecessary(cnv)
        # search/tweets.json の戻り値のquoted_statusのuserがたまにnullだゾ〜
        if msg[:quoted_status].is_a?(Hash) and msg[:quoted_status][:user]
          streaming_message(msg[:quoted_status]).add_quoted_by(message) end
        message end

      def messages(msgs)
        msgs.map{ |msg| message(msg) }
      end

      def user(u)
        cnv = u.convert_key(:screen_name =>:idname, :url => :url)
        cnv[:created] = Time.parse(u[:created_at]).localtime
        cnv[:detail] = u[:description]
        cnv[:protected] = !!u[:protected]
        cnv[:followers_count] = u[:followers_count].to_i
        cnv[:friends_count] = u[:friends_count].to_i
        cnv[:statuses_count] = u[:statuses_count].to_i
        cnv[:notifications] = u[:notifications]
        cnv[:verified] = u[:verified]
        cnv[:following] = u[:following]
        cnv[:exact] = [:created_at, :description, :protected, :followers_count, :friends_count, :verified].all?{|k|u.has_key?(k)}
        # ユーザの見た目が変わっても過去のTweetのアイコン等はそのままにしたいので、新しいUserを作る
        existing_user = Plugin::Twitter::User.findbyid(u[:id].to_i, Diva::DataSource::USE_LOCAL_ONLY)
        if visually_changed?(existing_user, cnv)
          Plugin::Twitter::User.new(existing_user.to_hash).merge(cnv)
        else
          cnv[:exact] ? Plugin::Twitter::User.rewind(cnv) : Plugin::Twitter::User.new_ifnecessary(cnv) end end

      def visually_changed?(old_user, new_user_hash)
        old_user && (
          old_user.idname != new_user_hash[:idname] ||
          old_user.name != new_user_hash[:name] ||
          old_user.profile_image_url != new_user_hash[:profile_image_url]) end
      private :visually_changed?

      def list(list)
        cnv = list.dup
        cnv[:mode] = list[:mode] == 'public'
        cnv[:user] = user(list[:user])
        cnv[:exact] = true
        cnv[:exact] ? Plugin::Twitter::UserList.rewind(cnv) : Plugin::Twitter::UserList.new_ifnecessary(cnv)
      end

      def direct_message(dm)
        cnv = dm.dup
        cnv[:user] = cnv[:sender] = user(dm[:sender])
        cnv[:recipient] = user(dm[:recipient])
        cnv[:exact] = true
        cnv[:created] = Time.parse(dm[:created_at]).localtime
        Plugin::Twitter::DirectMessage.new_ifnecessary(cnv) end

      def id(id)
        id end

    end

  end
end

class MikuTwitter; include MikuTwitter::ApiCallSupport end
