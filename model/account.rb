module Plugin::Worldon
  class AccountSource < Diva::Model
    #register :worldon_account_source, name: "Mastodonアカウント追加情報(Worldon)"

    field.string :privacy
    field.bool :sensitive
    field.string :note
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

    alias_method :perma_link, :url
    alias_method :uri, :url
    alias_method :idname, :acct
    alias_method :name, :display_name
    alias_method :description, :note

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

    def initialize(hash)
      hash[:created_at] = Time.parse(hash[:created_at]).localtime
      hash = self.class.regularize_acct(hash)

      # activity対策
      hash[:idname] = hash[:acct]

      super hash
    end

    def title
      "#{acct}(#{display_name})"
    end

    def icon
      Plugin.filtering(:photo_filter, avatar, [])[1].first
    end
  end
end
