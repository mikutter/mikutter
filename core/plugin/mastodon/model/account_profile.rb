# coding: utf-8
require 'cgi'

module Plugin::Mastodon
  class AccountProfile < Diva::Model
    extend Memoist
    include Diva::Model::MessageMixin

    register :mastodon_account_profile, name: "Mastodonアカウントプロフィール", timeline: true, myself: true

    field.has :account, Account, required: true
    alias :user :account

    attr_reader :description
    attr_reader :score

    def initialize(hash)
      super hash

      @description, @score = PM::Parser.dictate_score(description_html, emojis: account.emojis)
    end

    def created
      account.created_at
    end

    def title
      account.display_name
    end

    memoize def description_html
      fields = ""
      if account.fields.size > 0
        fields = account.fields.map { |f|
          "#{CGI.escapeHTML(f.name)}：#{f.value}"
        }.join("<br>")
        fields = "<p>#{fields}</p>"
      end

      paragraphs = [
        "<p>#{CGI.escapeHTML(account.display_name)}<br>#{account.acct}#{account.bot ? "<br>Bot" : ""}</p>",
        "#{account.note}"
      ]
      paragraphs.push fields unless fields.empty?
      paragraphs.push "<p>#{account.statuses_count} トゥート<br>#{account.following_count} フォロー<br>#{account.followers_count} フォロワー</p>"
      paragraphs.join('')
    end

    def perma_link
      account.url
    end

    def uri
      account.url
    end

    def from_me_world
      world = Plugin.filtering(:world_current, nil).first
      return nil if (!world.respond_to?(:account) || !world.account.respond_to?(:acct))
      return nil if account.acct != world.account.acct
      world
    end

    def from_me?(world = nil)
      if world
        if world.is_a? Plugin::Mastodon::World
          return account.acct == world.account.acct
        else
          return false
        end
      end
      !!from_me_world
    end
  end
end

