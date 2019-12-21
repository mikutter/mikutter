# coding: utf-8
require 'cgi'

module Plugin::Mastodon
  class AccountProfile < Diva::Model
    extend Memoist
    include Diva::Model::MessageMixin

    register :mastodon_account_profile, name: Plugin[:mastodon]._('Mastodonアカウントプロフィール'), timeline: true, myself: true

    field.has :account, Account, required: true
    alias :user :account

    attr_reader :description
    attr_reader :score

    def initialize(hash)
      super hash

      @description, @score = PM::Parser.dictate_score(account.note, emojis: account.emojis)
    end

    def created
      account.created_at
    end

    def title
      account.display_name
    end

    def perma_link
      account.url
    end

    def uri
      account.url
    end
  end
end

