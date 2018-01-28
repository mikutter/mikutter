require_relative 'entity_class'

module Plugin::Worldon
  # https://github.com/tootsuite/documentation/blob/master/Using-the-API/API.md#application
  class Application < Diva::Model
    register :worldon_application, name: "Mastodonアプリケーション(Worldon)"

    field.string :name, required: true
    field.uri :website
  end

  # https://github.com/tootsuite/documentation/blob/master/Using-the-API/API.md#emoji
  class Emoji < Diva::Model
    register :worldon_emoji, name: "Mastodon絵文字(Worldon)"

    field.string :shortcode, required: true
    field.uri :static_url, required: true
    field.uri :url, required: true
  end

  # https://github.com/tootsuite/documentation/blob/master/Using-the-API/API.md#attachment
  class Attachment < Diva::Model
    register :worldon_attachment, name: "Mastodon添付メディア(Worldon)"

    field.string :id, required: true
    field.string :type, required: true
    field.uri :url
    field.uri :remote_url
    field.uri :preview_url, required: true
    field.uri :text_url
    field.string :description

    attr_accessor :meta

    def initialize(hash)
      @meta = hash[:meta]
      hash.delete :meta
      super hash
    end
  end

  # https://github.com/tootsuite/documentation/blob/master/Using-the-API/API.md#mention
  class Mention < Diva::Model
    register :worldon_mention, name: "Mastodonメンション(Worldon)"

    field.uri :url, required: true
    field.string :username, required: true
    field.string :acct, required: true
    field.string :id, required: true
  end

  # https://github.com/tootsuite/documentation/blob/master/Using-the-API/API.md#tag
  class Tag < Diva::Model
    register :worldon_tag, name: "Mastodonタグ(Worldon)"

    field.string :name, required: true
    field.uri :url, required: true
  end

  class Icon < Diva::Model
    include Diva::Model::PhotoMixin

    register :worldon_icon, name: "Mastodonアカウントアイコン(Worldon)"

    field.uri :uri

    handle ->uri{
      uri.path.start_with?('/system/accounts/avatars/')
    } do |uri|
      new(uri: uri)
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

    alias_method :perma_link, :url
    alias_method :uri, :url
    alias_method :idname, :acct
    alias_method :name, :display_name

    def initialize(hash)
      hash[:created_at] = Time.parse(hash[:created_at]).localtime
      if hash[:acct].index('@').nil?
        hash[:acct] = hash[:acct] + '@' + Diva::URI.new(hash[:url]).host
      end
      super hash
    end

    def title
      "#{acct}(#{display_name})"
    end

    def icon
      Plugin::Worldon::Icon.new_ifnecessary(uri: avatar)
      #Skin['list.png']
    end

    def description
      # TODO: Account.noteを返す
      ''
    end
  end

  # https://github.com/tootsuite/documentation/blob/master/Using-the-API/API.md#status
  class Status < Diva::Model
    include Diva::Model::MessageMixin

    register :worldon_status, name: "Mastodonステータス(Worldon)", timeline: true, reply: true, myself: true

    field.string :id, required: true
    field.string :uri, required: true
    field.uri :url, required: true
    field.has :account, Plugin::Worldon::Account, required: true
    field.string :in_reply_to_id
    field.string :in_reply_to_account_id
    field.has :reblog, Plugin::Worldon::Status
    field.string :content, required: true
    field.time :created_at, required: true
    field.int :reblogs_count
    field.int :favourites_count
    field.bool :reblogged
    field.bool :favourited
    field.bool :muted
    field.bool :sensitive
    field.string :visibility
    field.bool :sensitive?
    field.string :spoiler_text
    field.string :visibility
    field.has :application, Application
    field.string :language
    field.bool :pinned

    alias_method :created, :created_at
    alias_method :perma_link, :url
    alias_method :retweeted?, :reblogged
    alias_method :favorited?, :favourited
    alias_method :muted?, :muted
    alias_method :pinned?, :pinned

    attr_accessor :emojis
    attr_accessor :media_attachments
    attr_accessor :mentions
    attr_accessor :tags

    entity_class MastodonEntity

    class << self
      def build(json)
        return [] if json.nil?
        json.map do |record|
          Status.new_ifnecessary(record)
        end
      end
    end

    def initialize(hash)
      hash[:created_at] = Time.parse(hash[:created_at]).localtime

      @emojis = hash[:emojis].map { |v| Emoji.new_ifnecessary(v) }
      @media_attachments = hash[:media_attachments].map { |v| Attachment.new_ifnecessary(v) }
      @mentions = hash[:mentions].map { |v| Mention.new_ifnecessary(v) }
      @tags = hash[:tags].map { |v| Tag.new_ifnecessary(v) }
      hash.delete :emojis
      hash.delete :media_attachments
      hash.delete :mentions
      hash.delete :tags
      super hash
    end

    def actual_status
      if reblog.nil?
        self
      else
        reblog
      end
    end

    def user
      actual_status.account
    end

    def retweet_count
      actual_status.reblogs_count
    end

    def favorite_count
      actual_status.favourites_count
    end

    def retweeted_by
      if reblog.nil?
        []
      else
        [account]
      end
    end

    def sensitive?
      actual_status.sensitive
    end

    def dehtmlize(text)
      text
        .gsub(/^<p>|<\/p>$|<\/?span[^>]*>|/, '')
        .gsub(/<br[^>]*>|<\/p><p>/) { "\n" }
    end

    def description
      msg = actual_status
      desc = dehtmlize(msg.content)
      if !msg.spoiler_text.nil? && msg.spoiler_text.size > 0
        desc = dehtmlize(msg.spoiler_text) + "\n----\n" + desc
      end
      desc
    end

    # register reply:true用API
    def mentioned_by_me?
      # TODO: Status.in_reply_to_account_id と current_world（もしくは受信時のworld？）を見てどうにかする
      false
    end

    # register myself:true用API
    def myself?
      # TODO: Status.account と current_world（もしくは受信時のworld？）を見てどうにかする
      false
    end

    # Basis Model API
    def title
      msg = actual_status
      if !msg.spoiler_text.nil? && msg.spoiler_text.size > 0
        msg.spoiler_text
      else
        msg.content
      end
    end
  end
end
