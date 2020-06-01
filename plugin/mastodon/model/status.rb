# coding: utf-8

module Plugin::Mastodon
  # https://github.com/tootsuite/documentation/blob/master/Using-the-API/API.md#status
  # 必ずStatus.buildメソッドを通して生成すること
  class Status < Diva::Model
    extend Gem::Deprecate
    include Diva::Model::MessageMixin

    register :mastodon_status, name: Plugin[:mastodon]._('トゥート'), timeline: true, reply: true, myself: true

    field.string :id, required: true
    field.string :original_uri, required: true # APIから取得するfediverse uniqueなURI文字列
    field.uri :url, required: true
    field.has :account, Account, required: true
    field.string :in_reply_to_id
    field.string :in_reply_to_account_id
    field.has :reblog, Status
    field.string :content, required: true
    field.time :created_at, required: true
    field.time :modified
    field.time :created
    field.int :reblogs_count
    field.int :favourites_count
    field.bool :reblogged
    field.bool :favourited
    field.bool :muted
    field.bool :sensitive
    field.string :spoiler_text
    field.string :visibility
    field.has :application, Application
    field.string :language
    field.bool :pinned

    field.string :domain, required: true # APIには無い追加フィールド

    field.has :emojis, [Emoji]
    field.has :media_attachments, [Attachment]
    field.has :mentions, [Mention]
    field.has :tags, [Tag]
    field.has :card, Card
    field.has :poll, Poll

    attr_accessor :reblog_status_uris # :: [String] APIには無い追加フィールド
      # ブーストしたStatusのuri（これらはreblogフィールドの値としてこのオブジェクトを持つ）と、acctを保持する。
    attr_accessor :favorite_accts # :: [String] APIには無い追加フィールド
    attr_accessor :description
    attr_accessor :score

    alias :uri :url # mikutter側の都合で、URI.parse可能である必要がある（API仕様上のuriフィールドとは異なる）。
    alias :perma_link :url
    alias :muted? :muted
    alias :pinned? :pinned
    alias :retweet_ancestor :reblog
    alias :sensitive? :sensitive # NSFW系プラグイン用

    @@mute_mutex = Thread::Mutex.new

    TOOT_URI_RE = %r!\Ahttps://([^/]+)/@\w{1,30}/(\d+)\z!.freeze
    TOOT_ACTIVITY_URI_RE = %r!\Ahttps://(?<domain>[^/]*)/users/(?<acct>[^/]*)/statuses/(?<status_id>[^/]*)/activity\z!.freeze

    handle TOOT_URI_RE do |uri|
      Status.findbyuri(uri) || Status.fetch(uri)
    end

    class << self
      @@status_storage = WeakStorage.new(String, Status, name: 'toot')

      def add_status_storage(toot)
        raise "uri must not nil. but given #{toot.uri.inspect}" unless toot.uri
        if @@status_storage.has_key?("#{toot.domain}:#{toot.uri}")
          warn "key already exists: #{toot.domain}:#{toot.uri}"
        end
        @@status_storage["#{toot.domain}:#{toot.uri}"] = toot
      end

      # urlで検索する。
      # 但しブーストの場合はfediverse uri
      def findbyuri(uri, domain: nil)
        domain ||= Diva::URI(uri).host
        @@status_storage["#{domain}:#{uri}"]
      end

      def add_mutes(account_hashes)
        @@mute_mutex.synchronize {
          @@mutes ||= []
          @@mutes += account_hashes.map do |hash|
            hash = Account.regularize_acct hash
            hash[:acct]
          end
          @@mutes = @@mutes.uniq
        }
      end

      def clear_mutes
        @@mute_mutex.synchronize {
          @@mutes = []
        }
      end

      def muted?(acct)
        @@mute_mutex.synchronize {
          @@mutes.any? { |a| a == acct }
        }
      end

      # Mastodon APIレスポンスのJSONをパースした結果のHashを受け取り、それに対応する
      # インスタンスを返す。
      # ==== Args
      # [server] Mastodonサーバ (Plugin::Mastodon::Instance)
      # [record] APIレスポンスのstatusオブジェクト (Hash)
      # ==== Return
      # Plugin::Mastodon::Status
      def build(server, record)
        json2status(server.domain, record)
      end

      # buildと似ているが、配列を受け取って複数のインスタンスを同時に取得できる。
      # ==== Args
      # [server] Mastodonサーバ (Plugin::Mastodon::Instance)
      # [json] APIレスポンスのstatusオブジェクトの配列 (Array)
      # ==== Return
      # Plugin::Mastodon::Status の配列
      def bulk_build(server, json)
        json.map do |record|
          build(server, record)
        end.to_a
      end

      def json2status(domain_name, record)
        record[:domain] = domain_name
        is_boost = false

        if record[:reblog]
          is_boost = true

          boost_record = Plugin::Mastodon::Util.deep_dup(record)
          boost_record[:reblog] = nil

          record = record[:reblog]
          record[:domain] = domain_name
        end
        uri = record[:url] # quoting_messages等のために@@status_storageには:urlで入れておく

        status = merge_or_create(domain_name, uri, record)
        return nil unless status

        # ブーストの処理
        if !is_boost
          status
            # ブーストではないので、普通にstatusを返す。
        else
          boost_uri = boost_record[:uri] # reblogには:urlが無いので:uriで入れておく
          boost = merge_or_create(domain_name, boost_uri, {**boost_record, url: boost_uri})
          return nil unless boost
          status.reblog_status_uris << { uri: boost_uri, acct: boost_record[:account][:acct] }
          status.reblog_status_uris.uniq!

          # ageなどの対応
          status.set_modified(boost.modified) if UserConfig[:retweeted_by_anyone_age] and (UserConfig[:retweeted_by_myself_age] or !boost.account.me?)

          boost[:retweet] = boost.reblog = status
            # わかりづらいが「ブーストした」statusの'reblog'プロパティにブースト元のstatusを入れている
          boost
            # 「ブーストした」statusを返す（appearしたのはそれに間違いないので。ブースト元はdon't care。
            # Gtk::TimeLine#block_addではmessage.retweet?ならmessage.retweet_sourceを取り出して追加する。
        end
      end

      def merge_or_create(domain_name, uri, new_hash)
        @@mutes ||= []
        if new_hash[:account] && new_hash[:account][:acct]
          account_hash = Account.regularize_acct(new_hash[:account])
          if @@mutes.index(account_hash[:acct])
            return nil
          end
        end

        status = findbyuri(uri, domain: domain_name)
        if status
          status = status.merge(domain_name, new_hash)
        else
          status = Status.new(new_hash)
        end
        status
      end

      def fetch(uri)
        if m = TOOT_URI_RE.match(uri.to_s)
          domain_name = m[1]
          id = m[2]
          Plugin::Mastodon::API.status(domain_name, id).next{ |resp|
            Status.build(Plugin::Mastodon::Instance.load(domain_name), resp.value)
          }
        else
          Delayer::Deferred.new(true).tap{|d| d.fail(nil) }
        end
      end
    end

    def initialize(hash)
      @reblog_status_uris = []
      @favorite_accts = []

      if hash[:created_at].is_a? String
        # タイムゾーン考慮
        hash[:created_at] = Time.parse(hash[:created_at]).localtime
      end
      # cairo_sub_parts_message_base用
      hash[:created] = hash[:created_at]
      hash[:modified] = hash[:created_at] unless hash[:modified]

      # mikutterはuriをURI型であるとみなす
      hash[:original_uri] = hash[:uri]
      hash.delete :uri

      # sub_parts_client用
      if hash[:application] && hash[:application][:name]
        hash[:source] = hash[:application][:name]
      end

      # Mentionのacctにドメイン付加
      if hash[:mentions]
        hash[:mentions].each_index do |i|
          acct = hash[:mentions][i][:acct]
          hash[:mentions][i][:acct] = Account.regularize_acct_by_domain(hash[:domain], acct)
        end
      end

      # notification用
      hash[:retweet] = hash[:reblog]

      super hash

      self[:user] = self[:account]
      if self.reblog.is_a?(Status) && self.reblog.account.is_a?(Account)
        self.reblog[:user] = self.reblog.account
      end

      @emoji_score = Hash.new

      content = actual_status.content
      unless spoiler_text.empty?
        content = spoiler_text + "<br>----<br>" + content
      end
      @description, @score = Plugin::Mastodon::Parser.dictate_score(content, mentions: mentions, emojis: emojis, media_attachments: media_attachments, poll: poll)

      self.class.add_status_storage(self)
      Plugin.call(:mastodon_appear_toots, [self])
    end

    def inspect
      "mastodon-status(#{uri} #{description})"
    end

    def merge(domain_name, new_hash)
      # 取得元が発言者の所属サーバーであれば優先する
      account_domain = account&.domain
      account_domain2 = Account.domain(new_hash[:account][:url])
      if !domain || domain != account_domain && domain_name == account_domain2
        self.id = new_hash[:id]
        self.domain = domain_name
        if !(application && self[:source]) && new_hash[:application]
          self.application = Application.new(new_hash[:application])
          self[:source] = application.name
        end
      end
      reblogs_count = new_hash[:reblogs_count]
      favourites_count = new_hash[:favourites_count]
      pinned = new_hash[:pinned]
      self
    end

    def actual_status
      reblog || self
    end

    def icon
      actual_status.account.icon
    end

    def user
      account
    end

    def server
      @server ||= Plugin::Mastodon::Instance.load(domain)
    end

    def retweet_count
      actual_status.reblogs_count
    end

    def favorite_count
      actual_status.favourites_count
    end

    def retweet?
      reblog.is_a? Status
    end

    def retweeted_by
      actual_status.reblog_status_uris.map{|pair| pair[:acct] }.compact.uniq.map{|acct| Account.findbyacct(acct) }.compact
    end

    def shared?(counterpart=nil)
      counterpart ||= Plugin.filtering(:world_current, nil).first
      if counterpart.respond_to?(:user_obj)
        counterpart = counterpart.user_obj
      end
      if counterpart.is_a?(Account)
        actual_status.retweeted_by.include?(counterpart)
      end
    end

    alias :retweeted? :shared?

    def favorited_by
      @favorite_accts.map{|acct| Account.findbyacct(acct) }.compact.uniq
    end

    def favorite?(counterpart = nil)
      counterpart ||= Plugin.filtering(:world_current, nil).first
      if counterpart.respond_to?(:user_obj)
        counterpart = counterpart.user_obj
      end

      if counterpart.is_a?(Account)
        @favorite_accts.include?(counterpart.idname)
      end
    end

    # sub_parts_client用
    def source
      actual_status.application&.name
    end

    def add_attachments(text)
      if media_attachments && !media_attachments.empty?
        media_attachments.each do |attachment|
          url = attachment.text_url || attachment.url
          if !text.include?(url.to_s)
            text += " <a href=\"#{url}\">#{url}</a>"
          end
        end
      end
      text
    end

    # 自分が _self_ にリプライを返していればtrue
    def mentioned_by_me?
      children.any?(&:from_me?)
    end

    # _self_ を宛先としたStatusのリストを返す
    def children
      @children ||= Set.new(retweeted_statuses)
    end

    protected def add_child(child)
      children << child
    end

    # この投稿の投稿主のアカウントの全権限を所有していればtrueを返す
    def from_me?(world = Plugin.collect(:worlds))
      account.me?(world)
    end

    # 通知用
    # 自分へのmention
    def mention_to_me?(world)
      return false if mentions.empty?
      return false if (!world.respond_to?(:account) || !world.account.respond_to?(:acct))
      mentions.map{|mention| mention.acct }.include?(world.account.acct)
    end

    # 自分へのreblog
    def reblog_to_me?(world)
      return false unless reblog
      reblog.from_me?(world)
    end

    def to_me_world
      world = Plugin.filtering(:world_current, nil).first
      return nil if (!mention_to_me?(world) && !reblog_to_me?(world))
      world
    end

    def to_me?(world = nil)
      if world
        if world.is_a? Plugin::Mastodon::World
          return mention_to_me?(world) || reblog_to_me?(world)
        else
          return false
        end
      end
      !!to_me_world
    end

    # activity用
    def to_s
      description
    end

    # ふぁぼ
    def favorite(do_fav)
      world, = Plugin.filtering(:world_current, nil)
      if do_fav
        Plugin[:mastodon].favorite(world, self)
      else
        Plugin[:mastodon].unfavorite(world, self)
      end
    end

    def retweeted_statuses
      reblog_status_uris.map{|pair| self.class.findbyuri(pair[:uri]) }.compact
    end

    alias :retweeted_sources :retweeted_statuses

    # Message#.introducer
    # 本当はreblogがあればreblogをreblogした最後のStatusを返す
    # reblogがなければselfを返す
    def introducer(world = nil)
      self
    end

    # 返信スレッド用
    def around(force_retrieve=false)
      if force_retrieve
        resp = Plugin::Mastodon::API.call!(:get, domain, '/api/v1/statuses/' + id + '/context')
        return [self] unless resp
        @around = [*Status.bulk_build(server, resp[:ancestors]),
                   self,
                   *Status.bulk_build(server, resp[:descendants])]
      else
        @around || [self]
      end
    end

    # tootのリプライ先を再帰的に遡って、見つかった順に列挙する。
    # 最初に列挙する要素は常に _self_ で、ある要素は次の要素へのリプライとなっている。
    # ==== Args
    # [force_retrieve] サーバへの問い合わせを許可するフラグ
    # ==== Return
    # Enumerator :: リプライツリーを祖先方向に辿って列挙する (Plugin::Mastodon::Status)
    def ancestors(force_retrieve=false)
      if force_retrieve
        @ancestors ||= ancestors_force.to_a.freeze
      else
        [self, *replyto_source&.ancestors].freeze
      end
    end

    private def ancestors_force
      resp = Plugin::Mastodon::API.call!(:get, domain, '/api/v1/statuses/' + id + '/context')
      if resp
        [self, *Status.bulk_build(server, resp[:ancestors]).reverse]
      else
        [self]
      end
    end

    # 返信表示用
    def has_receive_message?
      !!in_reply_to_id
    end

    def repliable?(counterpart=nil)
      true
    end

    # 返信表示用
    def replyto_source(force_retrieve=false)
      # TODO: サーバ+IDでStatusを保存するWeakStoreを使ってキャッシュしたいわね
      @replyto_source ||=
        force_retrieve ? replyto_source_force : nil
    end

    private def replyto_source_force
      unless domain
        # 何故かreplyviewerに渡されたStatusからdomainが消失することがあるので復元を試みる
        world, = Plugin.filtering(:mastodon_current, nil)
        if world
          # 見つかったworldでstatusを取得し、id, domain, in_reply_to_idを上書きする。
          status = Plugin::Mastodon::API.status_by_url!(world.domain, world.access_token, url)
          if status
            self[:id] = status[:id]
            self[:domain] = world.domain
            self[:in_reply_to_id] = status[:in_reply_to_id]
            if status[:reblog]
              self.reblog[:id] = status[:reblog][:id]
              self.reblog[:domain] = world.domain
              self.reblog[:in_reply_to_id] = status[:reblog][:in_reply_to_id]
            end
          end
        end
      end
      Plugin::Mastodon::API.status!(domain, in_reply_to_id)
        &.yield_self { |r| Status.build(server, r.value) }
        &.tap { |parent| parent.add_child(self) }
    end

    # 返信表示用
    def replyto_source_d(force_retrieve=true)
      promise = Delayer::Deferred.new(true)
      Thread.new do
        result = replyto_source(force_retrieve)
        if result.is_a? Status
          promise.call(result)
        else
          promise.fail(result)
        end
      rescue Exception => e
        promise.fail(e)
      end
      promise
    end

    def retweet_source(force_retrieve=false)
      reblog
    end

    def retweet_source_d(force_retrieve=false)
      promise = Delayer::Deferred.new(true)
      Thread.new do
        if reblog.is_a? Status
          promise.call(reblog)
        else
          promise.fail(reblog)
        end
      rescue Exception => e
        promise.fail(e)
      end
      promise
    end

    def retweet_ancestors(force_retrieve=false)
      if reblog.is_a? Status
        [self, reblog]
      else
        [self]
      end
    end

    def rebloggable?(world = nil)
      !actual_status.shared?(world) && !['private', 'direct'].include?(actual_status.visibility)
    end

    # 最終更新日時を取得する
    def modified
      @value[:modified] ||= [created, *(@retweets || []).map{ |x| x.modified }].compact.max
    end
    # 最終更新日時を更新する
    def set_modified(time)
      if modified < time
        self[:modified] = time
        Plugin::call(:message_modified, self)
      end
      self
    end

    def post(message:, **kwrest)
      world, = Plugin.filtering(:world_current, nil)
      Plugin[:mastodon].compose(self, world, body: message, **kwrest)
    end
    deprecate :post, :none, 2018, 11

    def receive_user_idnames
      mentions.map(&:acct).to_a
    end
  end
end
