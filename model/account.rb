# coding: utf-8
module Plugin::Worldon
  class AccountSource < Diva::Model
    #register :worldon_account_source, name: "Mastodonアカウント追加情報(Worldon)"

    field.string :privacy
    field.bool :sensitive
    field.string :note
  end

  class AccountField < Diva::Model
    field.string :name
    field.string :value

    def inspect
      "#{name}: #{value}"
    end
  end

  # https://github.com/tootsuite/documentation/blob/master/Using-the-API/API.md#status
  class Account < Diva::Model
    include Diva::Model::UserMixin

    register :worldon_account, name: "Mastodonアカウント(Worldon)"

    field.string :id, required: true
    field.string :username, required: true
    field.string :acct, required: true
    field.string :display_name, required: true
    field.bool :locked, required: true
    field.bool :bot
    field.time :created_at, required: true
    field.int :followers_count, required: true
    field.int :following_count, required: true
    field.int :statuses_count, required: true
    field.string :note, required: true
    field.uri :url, required: true
    field.uri :avatar, required: true
    field.uri :avatar_static, required: true
    field.uri :header, required: true
    field.uri :header_static, required: true
    field.has :moved, Account
    field.has :source, AccountSource
    field.has :fields, [AccountField]

    alias :perma_link :url
    alias :uri :url
    alias :idname :acct
    alias :name :display_name
    alias :description :note

    @@account_storage = WeakStorage.new(String, Account)

    ACCOUNT_URI_RE = %r!\Ahttps://(?<domain>[^/]+)/@(?<acct>\w{1,30})\z!

    handle ACCOUNT_URI_RE do |uri|
      m = ACCOUNT_URI_RE.match(uri.to_s)
      acct = "#{m["acct"]}@#{m["domain"]}"
      account = Account.findbyacct(acct)
      next account if account

      Thread.new {
        Account.fetch(acct)
      }
    end

    def self.regularize_acct_by_domain(domain, acct)
      if acct.index('@').nil?
        acct = acct + '@' + domain
      end
      acct
    end

    def self.regularize_acct(hash)
      domain = Diva::URI.new(hash[:url]).host
      acct = hash[:acct]
      hash[:acct] = self.regularize_acct_by_domain(domain, acct)
      hash
    end

    def self.domain(url)
      Diva::URI.new(url.to_s).host
    end

    def self.findbyacct(acct)
      @@account_storage[acct]
    end

    def self.fetch(acct)
      world, = Plugin.filtering(:worldon_current, nil)
      resp = Plugin::Worldon::API.call(:get, world.domain, '/api/v1/search', world.access_token, q: acct, resolve: true)
      hash = resp[:accounts].select{|account| account[:acct] === acct }.first
      if hash
        Account.new hash
      end
    end

    def domain
      self.class.domain(url)
    end

    def initialize(hash)
      if hash[:created_at].is_a? String
        hash[:created_at] = Time.parse(hash[:created_at]).localtime
      end
      hash = self.class.regularize_acct(hash)

      # activity対策
      hash[:idname] = hash[:acct]

      hash[:name] = hash[:display_name]

      super hash

      @@account_storage[hash[:acct]] = self

      self
    end

    def inspect
      "worldon-account(#{acct})"
    end

    def title
      "#{acct}(#{display_name})"
    end

    def icon
      Enumerator.new{|y|
        Plugin.filtering(:photo_filter, avatar_static, y)
      }.lazy.map{|photo|
        Plugin.filtering(:miracle_icon_filter, photo)[0]
      }.first
    end

    def me?
      world = Plugin.filtering(:world_current, nil).first
      world.class.slug == :worldon && world.account.acct == acct
    end
  end
end
