require_relative 'entity_class'

module Plugin::Worldon
  # https://github.com/tootsuite/documentation/blob/master/Using-the-API/API.md#status
  # 必ずStatus.buildメソッドを通して生成すること
  class Status < Diva::Model
    include Diva::Model::MessageMixin

    register :worldon_status, name: "Mastodonステータス(Worldon)", timeline: true, reply: true, myself: true

    field.string :id, required: true
    field.string :original_uri, required: true # APIから取得するfediverse uniqueなURI文字列
    field.uri :url, required: true
    field.has :account, Account, required: true
    field.string :in_reply_to_id
    field.string :in_reply_to_account_id
    field.has :reblog, Status
    field.string :content, required: true
    field.time :created_at, required: true
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

    attr_accessor :reblog_status_uris # :: [String] APIには無い追加フィールド
      # ブーストしたStatusのuri（これらはreblogフィールドの値としてこのオブジェクトを持つ）。

    alias_method :uri, :url # mikutter側の都合で、URI.parse可能である必要がある（API仕様上のuriフィールドとは異なる）。
    alias_method :perma_link, :url
    alias_method :shared?, :reblogged
    alias_method :favorite?, :favourited
    alias_method :muted?, :muted
    alias_method :pinned?, :pinned
    alias_method :retweet_ancestor, :reblog
    alias_method :sensitive?, :sensitive # NSFW系プラグイン用

    @mute_mutex = Thread::Mutex.new

    entity_class MastodonEntity

    @@status_storage = WeakStorage.new(String, Status)

    class << self
      def add_mutes(account_hashes)
        @mute_mutex.synchronize {
          @mutes ||= []
          @mutes += account_hashes.map do |hash|
            hash = Account.regularize_acct hash
            hash[:acct]
          end
          @mutes = @mutes.uniq
          #pp @mutes
        }
      end

      def build(domain_name, json)
        return [] if json.nil?
        return build(domain_name, [json]) if json.is_a? Hash

        json.map do |record|
          json2status(domain_name, record)
        end.compact.tap do |statuses|
          Plugin.call(:worldon_appear_toots, statuses)
        end
      end

      def json2status(domain_name, record)
        record[:domain] = domain_name
        is_boost = false

        if record[:reblog]
          is_boost = true

          boost_record = Util.deep_dup(record)
          boost_record[:reblog] = nil

          record = record[:reblog]
          record[:domain] = domain_name
        end
        uri = record[:url] # quoting_messages等のために@@status_storageには:urlで入れておく

        status = merge_or_create(domain_name, uri, record)

        # ブーストの処理
        if !is_boost
          status
            # ブーストではないので、普通にstatusを返す。
        else
          boost_uri = boost_record[:uri] # reblogには:urlが無いので:uriで入れておく
          boost = merge_or_create(domain_name, boost_uri, boost_record)

          status.reblog_status_uris = status.reblog_status_uris << boost_uri

          boost[:retweet] = boost.reblog = status
            # わかりづらいが「ブーストした」statusの'reblog'プロパティにブースト元のstatusを入れている
          @@status_storage[boost_uri] = boost
          boost
            # 「ブーストした」statusを返す（appearしたのはそれに間違いないので。ブースト元はdon't care。
            # Gtk::TimeLine#block_addではmessage.retweet?ならmessage.retweet_sourceを取り出して追加する。
        end
      end

      # urlで検索する。
      # 但しブーストの場合はfediverse uri
      def findbyurl(url)
        @@status_storage[url]
      end

      def merge_or_create(domain_name, uri, new_hash)
        status = @@status_storage[uri]
        if status
          status = status.merge(domain_name, new_hash)
        else
          status = Status.new(new_hash)
        end
        @@status_storage[uri] = status
        status
      end
    end

    def initialize(hash)
      @mutes ||= []
      if hash[:account] && hash[:account][:acct]
        account_hash = Account.regularize_acct(hash[:account])
        if @mutes.index(account_hash[:acct])
          return nil
        end
      end

      @reblog_status_uris = []

      # タイムゾーン考慮
      hash[:created_at] = Time.parse(hash[:created_at]).localtime
      # cairo_sub_parts_message_base用
      hash[:created] = hash[:created_at]

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
    end

    def merge(domain_name, new_hash)
      # 取得元が発言者の所属インスタンスであれば優先する
      account_domain = account&.domain
      account_domain2 = Account.domain(new_hash[:account][:url])
      if domain.nil? || domain != account_domain && domain_name == account_domain2
        self.id = new_hash[:id]
        self.domain = domain_name
        if (application.nil? || self[:source].nil?) && new_hash[:application]
          self.application = Application.new(new_hash[:application])
          self[:source] = application.name
        end
      end
      reblogs_count = new_hash[:reblogs_count]
      favourites_count = new_hash[:favourites_count]
      self
    end

    def actual_status
      if reblog.nil?
        self
      else
        reblog
      end
    end

    def user
      account
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
      actual_status.reblog_status_uris.map{|uri| @@status_storage[uri]&.account }.compact.uniq{|account| account.acct }
    end

    # sub_parts_client用
    def source
      actual_status.application&.name
    end

    def dehtmlize(text)
      text
        .gsub(/<span class="ellipsis">([^<]*)<\/span>/) {|s| $1 + "..." }
        .gsub(/^<p>|<\/p>|<span class="invisible">[^<]*<\/span>|<\/?span[^>]*>/, '')
        .gsub(/<br[^>]*>|<p>/) { "\n" }
        .gsub(/&apos;/) { "'" }
        .gsub(/(<a[^>]*)(?: rel="[^>"]*"| target="[^>"]*")/) { $1 }
        .gsub(/(<a[^>]*)(?: rel="[^>"]*"| target="[^>"]*")/) { $1 }
    end

    def add_attachments(text)
      if media_attachments && !media_attachments.empty?
        media_attachments.each do |attachment|
          url = attachment.text_url
          if url.nil?
            url = attachment.url
          end
          if !text.include?(url.to_s)
            text += " <a href=\"#{url}\">#{url}</a>"
          end
        end
      end
      text
    end

    def description
      if @description_text
        return @description_text
      end
      msg = actual_status
      desc = dehtmlize(msg.content)
      if !msg.spoiler_text.empty?
        desc = dehtmlize(msg.spoiler_text) + "\n----\n" + desc
      end
      desc = add_attachments(desc)
      @description_text = desc
    end

    # register reply:true用API
    def mentioned_by_me?
      !mentions.empty? && from_me?
    end

    def from_me_world
      worlds = Plugin.filtering(:worldon_worlds, nil).first
      return nil if worlds.nil?
      worlds.select{|world|
        account.acct == world.account.acct
      }.first
    end

    # register myself:true用API
    def from_me?(world = nil)
      if !world.nil?
        if world.is_a? Plugin::Worldon::World
          return account.acct == world.account.acct
        else
          return false
        end
      end
      !!from_me_world
    end

    # 通知用
    # 自分へのmention
    def mention_to_me?(world)
      return false if mentions.empty?
      mentions.map{|mention| mention.acct }.include?(world.account.acct)
    end

    # 自分へのreblog
    def reblog_to_me?(world)
      return false if reblog.nil?
      reblog.from_me?(world)
    end

    def to_me_world
      worlds = Plugin.filtering(:worldon_worlds, nil).first
      return nil if worlds.nil?
      worlds.select{|world|
        mention_to_me?(world) || reblog_to_me?(world)
      }.first
    end

    # mentionもしくはretweetが自分に向いている（twitter APIで言うreceiverフィールドが自分ということ）
    def to_me?(world = nil)
      if !world.nil?
        if world.is_a? Plugin::Worldon::World
          return mention_to_me?(world) || reblog_to_me?(world)
        else
          return false
        end
      end
      !to_me_world.nil?
    end

    # Basis Model API
    def title
      msg = actual_status
      if !msg.spoiler_text.empty?
        msg.spoiler_text
      else
        msg.content
      end
    end

    # activity用
    def to_s
      dehtmlize(title)
    end

    # ふぁぼ
    def favorite(do_fav)
      world, = Plugin.filtering(:world_current, nil)
      if do_fav
        Plugin[:worldon].favorite(world, self)
      else
        # TODO: unfavorite spell
      end
    end

    def retweeted_statuses
      reblog_status_uris.map{|uri| @@status_storage[uri] }.compact
    end

    # Message#.introducer
    # 本当はreblogがあればreblogをreblogした最後のStatusを返す
    # reblogがなければselfを返す
    def introducer(world = nil)
      self
    end

    # quoted_message用
    def quoting?
      content = actual_status.content
      r = %r!<a [^>]*href="https://(?:[^/]+/@[^/]+/\d+|(?:mobile\.)?twitter\.com/[_0-9A-Za-z/]+/status/\d+)"!.match(content)
      !r.nil?
    end

    # quoted_message用
    def quoting_messages(force_retrieve=false)
      content = actual_status.content
      matches = []
      regexp = %r!<a [^>]*href="(https://(?:[^/]+/@[^/]+/\d+|(?:mobile\.)?twitter\.com/[_0-9A-Za-z/]+/status/\d+))"!
      rest = content
      while m = regexp.match(rest)
        matches.push m.to_a
        rest = m.post_match
      end
      matches.map do |m|
        url = m[1]
        if url.index('twitter.com')
          has_twitter = Plugin.const_defined?('Plugin::Twitter::Message') &&
            Plugin::Twitter::Message.is_a?(Class) &&
            Enumerator.new{|y| Plugin.filtering(:worlds, y) }.any?{|world| world.class.slug == :twitter }

          if has_twitter
            m = %r!https://(?:mobile\.)?twitter\.com/[_0-9A-Za-z/]+/status/(\d+)!.match(url)
            next if m.nil?
            quoted_id = m[1]
            Plugin::Twitter::Message.findbyid(quoted_id, -1)
          end
        else
          m = %r!https://([^/]+)/@[^/]+/(\d+)!.match(url)
          next nil if m.nil?
          domain_name = m[1]
          id = m[2]
          resp = Plugin::Worldon::API.status(domain_name, id)
          next nil if resp.nil?
          Status.build(domain_name, [resp]).first
        end
      end.compact
    end

    # 返信スレッド用
    def around(force_retrieve=false)
      resp = Plugin::Worldon::API.call(:get, domain, '/api/v1/statuses/' + id + '/context')
      return [self] if resp.nil?
      ancestors = Status.build(domain, resp[:ancestors])
      descendants = Status.build(domain, resp[:descendants])
      ancestors + [self] + descendants
    end

    def ancestors(force_retrieve=false)
      resp = Plugin::Worldon::API.call(:get, domain, '/api/v1/statuses/' + id + '/context')
      return [self] if resp.nil?
      ancestors = Status.build(domain, resp[:ancestors])
      [self] + ancestors.reverse
    end

    # 返信表示用
    def has_receive_message?
      !in_reply_to_id.nil?
    end

    # 返信表示用
    def replyto_source(force_retrieve=false)
      if domain.nil?
        # 何故かreplyviewerに渡されたStatusからdomainが消失することがあるので復元を試みる
        world, = Plugin.filtering(:worldon_current, nil)
        if world
          # 見つかったworldでstatusを取得し、id, domain, in_reply_to_idを上書きする。
          status = Plugin::Worldon::API.status_by_url(world.domain, world.access_token, url)
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
      resp = Plugin::Worldon::API.status(domain, in_reply_to_id)
      return nil if resp.nil?
      Status.build(domain, [resp]).first
    end

    # 返信表示用
    def replyto_source_d(force_retrieve=true)
      promise = Delayer::Deferred.new(true)
      Thread.new do
        begin
          result = replyto_source(force_retrieve)
          if result.is_a? Status
            promise.call(result)
          else
            promise.fail(result)
          end
        rescue Exception => e
          promise.fail(e)
        end
      end
      promise
    end

    def retweet_source(force_retrieve=false)
      reblog
    end

    def retweet_source_d
      promise = Delayer::Deferred.new(true)
      Thread.new do
        begin
          if reblog.is_a? Status
            promise.call(reblog)
          else
            promise.fail(reblog)
          end
        rescue Exception => e
          promise.fail(e)
        end
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

    def rebloggable?
      !actual_status.shared? && actual_status.visibility != 'private' && actual_status.visibility != 'direct'
    end
  end
end
