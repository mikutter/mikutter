require_relative 'model'
require_relative 'api'

module Plugin::Worldon
  class World < Diva::Model
    register :worldon_for_mastodon, name: "Mastodonアカウント(Worldon)"

    field.string :id, required: true
    field.string :slug, required: true
    alias_method :name, :slug
    field.string :domain, required: true
    field.string :access_token, required: true
    field.has :account, Account, required: true

    def icon
      account.icon
    end

    def title
      account.title
    end

    def datasource_slug(type, n = nil)
      case type
      when :home
        # ホームTL
        "worldon-#{slug}-home".to_sym
      when :notification
        # 通知
        "worldon-#{slug}-notification".to_sym
      when :list
        # リストTL
        "worldon-#{slug}-list-#{n}".to_sym
      end
    end

    def get_lists!
      @lists ||= API.call(:get, domain, '/api/v1/lists', access_token)
      @lists
    end

    def lists
      @lists
    end

    # 投稿する
    # opts[:in_reply_to_id] Integer 返信先Statusの（ローカル）ID
    # opts[:media_ids] Array 添付画像IDの配列（最大4）
    # opts[:sensitive] True | False NSFWフラグの明示的な指定
    # opts[:spoiler_text] String ContentWarning用のコメント
    # opts[:visibility] String 公開範囲。 "direct", "private", "unlisted", "public" のいずれか。
    def post(content, **opts)
      opts[:status] = content
      API.call(:post, domain, '/api/v1/statuses', access_token, opts)
    end
  end
end
