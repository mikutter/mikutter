# coding: utf-8
require 'cgi' # unescapeHTML

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
      # ブーストしたStatusのuri（これらはreblogフィールドの値としてこのオブジェクトを持つ）と、acctを保持する。
    attr_accessor :favorite_accts # :: [String] APIには無い追加フィールド
    attr_accessor :description
    attr_accessor :score

    alias_method :uri, :url # mikutter側の都合で、URI.parse可能である必要がある（API仕様上のuriフィールドとは異なる）。
    alias_method :perma_link, :url
    alias_method :muted?, :muted
    alias_method :pinned?, :pinned
    alias_method :retweet_ancestor, :reblog
    alias_method :sensitive?, :sensitive # NSFW系プラグイン用

    @mute_mutex = Thread::Mutex.new

    @@status_storage = WeakStorage.new(String, Status)

    TOOT_URI_RE = %r!\Ahttps://([^/]+)/@\w{1,30}/(\d+)\z!

    handle TOOT_URI_RE do |uri|
      Status.findbyurl(uri) || Thread.new { Status.fetch(uri) }
    end

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

          status.reblog_status_uris << { uri: boost_uri, acct: boost_record[:account][:acct] }
          status.reblog_status_uris.uniq!

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

      def fetch(uri)
        if m = TOOT_URI_RE.match(uri.to_s)
          domain_name = m[1]
          id = m[2]
          resp = Plugin::Worldon::API.status(domain_name, id)
          return nil if resp.nil?
          Status.build(domain_name, [resp]).first
        end
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
      @favorite_accts = []

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

      @emoji_score = Hash.new
      dictate_score

      self
    end

    def inspect
      "worldon-status(#{description})"
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

    def icon
      actual_status.account.icon
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
      actual_status.reblog_status_uris.map{|pair| pair[:acct] }.compact.uniq.map{|acct| Account.findbyacct(acct) }.compact
    end

    def shared?(counterpart = nil)
      if counterpart.nil?
        counterpart = Plugin.filtering(:world_current, nil).first
      end
      if counterpart.respond_to?(:user_obj)
        counterpart = counterpart.user_obj
      end
      if counterpart.is_a?(Account)
        actual_status.retweeted_by.include?(counterpart)
      end
    end

    alias_method :retweeted?, :shared?

    def favorited_by
      @favorite_accts.map{|acct| Account.findbyacct(acct) }.compact.uniq
    end

    def favorite?(counterpart = nil)
      if counterpart.nil?
        counterpart = Plugin.filtering(:world_current, nil).first
      end
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

    def dehtmlize(text)
      result = text
        .gsub(/<span class="ellipsis">([^<]*)<\/span>/) {|s| $1 + "..." }
        .gsub(/^<p>|<\/p>|<span class="invisible">[^<]*<\/span>|<\/?span[^>]*>/, '')
        .gsub(/<br[^>]*>|<p>/) { "\n" }
        .gsub(/&apos;/) { "'" }
        .gsub(/(<a[^>]*)(?: rel="[^>"]*"| target="[^>"]*")/) { $1 }
      result
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

    # register reply:true用API
    def mentioned_by_me?
      !mentions.empty? && from_me?
    end

    def from_me_world
      world = Plugin.filtering(:world_current, nil).first
      return nil if (!world.respond_to?(:account) || !world.account.respond_to?(:acct))
      return nil if account.acct != world.account.acct
      world
    end

    # register myself:true用API
    def from_me?(world = nil)
      if world
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
      return false if (!world.respond_to?(:account) || !world.account.respond_to?(:acct))
      mentions.map{|mention| mention.acct }.include?(world.account.acct)
    end

    # 自分へのreblog
    def reblog_to_me?(world)
      return false if reblog.nil?
      reblog.from_me?(world)
    end

    def to_me_world
      world = Plugin.filtering(:world_current, nil).first
      return nil if (!mention_to_me?(world) && !reblog_to_me?(world))
      world
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

    # activity用
    def to_s
      description
    end

    # ふぁぼ
    def favorite(do_fav)
      world, = Plugin.filtering(:world_current, nil)
      if do_fav
        Plugin[:worldon].favorite(world, self)
      else
        Plugin[:worldon].unfavorite(world, self)
      end
    end

    def retweeted_statuses
      reblog_status_uris.map{|pair| @@status_storage[pair[:uri]] }.compact
    end

    alias_method :retweeted_sources, :retweeted_statuses

    # Message#.introducer
    # 本当はreblogがあればreblogをreblogした最後のStatusを返す
    # reblogがなければselfを返す
    def introducer(world = nil)
      self
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

    def rebloggable?(world = nil)
      !actual_status.shared?(world) && !['private', 'direct'].include?(actual_status.visibility)
    end

    # <a>タグ（のみ）を処理したscoreを構築する
    # emojiは別途行なう
    def dictate_score
      msg = actual_status
      desc = dehtmlize(msg.content)
      if !msg.spoiler_text.empty?
        # TODO: CW用のNoteを実現する方法がある？
        desc = dehtmlize(msg.spoiler_text) + "\n----\n" + desc
      end

      score = []

      # リンク処理
      # TODO: user_detail_viewを作ったらacctをAccount Modelにする
      # TODO: search spellを作ったらハッシュタグをなんかそれっぽいModelにする
      pos = 0
      anchor_re = %r|<a [^>]*href="(?<url>[^"]*)"[^>]*>(?<text>[^<]*)</a>|
      urls = []
      while m = anchor_re.match(desc, pos)
        anchor_begin = m.begin(0)
        anchor_end = m.end(0)
        if pos < anchor_begin
          score << Plugin::Score::TextNote.new(description: CGI.unescapeHTML(desc[pos...anchor_begin]))
        end
        url = CGI.unescapeHTML(m["url"])
        score << Plugin::Score::HyperLinkNote.new(
          description: CGI.unescapeHTML(m["text"]),
          uri: url,
        )
        urls << url
        pos = anchor_end
      end
      if pos < desc.size
        score << Plugin::Score::TextNote.new(description: CGI.unescapeHTML(desc[pos...desc.size]))
      end

      # 添付ファイル用のwork around
      # TODO: mikutter本体側が添付ファイル用のNoteを用意したらそちらに移行する
      if media_attachments.size > 0
        media_attachments
          .select {|attachment|
            !urls.include?(attachment.url.to_s) && !urls.include?(attachment.text_url.to_s)
          }
          .each {|attachment|
            score << Plugin::Score::TextNote.new(description: "\n")

            description = attachment.text_url
            if !description
              description = attachment.url
            end
            score << Plugin::Score::HyperLinkNote.new(description: description, uri: attachment.url)
          }
      end

      score = score.flat_map do |note|
        if !note.is_a?(Plugin::Score::TextNote)
          [note]
        else
          emoji_score = Enumerator.new{|y|
            dictate_emoji(note.description, y)
          }.first.to_a
          if emoji_score.size > 0
            emoji_score
          else
            [note]
          end
        end
      end

      @description = score.inject('') { |desc, note| desc + note.description }
      @score = score
    end

    # 与えられたテキスト断片に対し、このStatusが持っているemoji情報でscoreを返します。
    def dictate_emoji(text, yielder)
      if @emoji_score[text]
        score = @emoji_score[text]
        if (score.size > 1 || score.size == 1 && !score[0].is_a?(Plugin::Score::TextNote))
          yielder << score
        end
        return yielder
      end

      score = emojis.inject(Array(text)){ |fragments, emoji|
        shortcode = ":#{emoji.shortcode}:"
        fragments.flat_map{|fragment|
          if fragment.is_a?(String)
            if fragment === shortcode
              [emoji]
            else
              sub_fragments = fragment.split(shortcode).flat_map{|str|
                [str, emoji]
              }
              sub_fragments.pop unless fragment.end_with?(shortcode)
              sub_fragments
            end
          else
            [fragment]
          end
        }
      }.map{|chunk|
        if chunk.is_a?(String)
          Plugin::Score::TextNote.new(description: chunk)
        else
          chunk
        end
      }

      if (score.size > 1 || score.size == 1 && !score[0].is_a?(Plugin::Score::TextNote))
        yielder << score
      end
      @emoji_score[text] = score
    end

  end
end
