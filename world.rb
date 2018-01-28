require_relative 'model'

module Plugin::Worldon
  class World < Diva::Model
    register :worldon_for_mastodon, name: "Mastodonアカウント(Worldon)"

    field.string :id, required: true
    field.string :slug, required: true
    alias_method :name, :slug
    field.string :domain, required: true
    field.string :access_token, required: true
    field.has :account, Account, required: true

    # https://github.com/tootsuite/documentation/blob/master/Using-the-API/API.md#getting-the-current-user
    # TODO: 認証時に取得して保存
    # TODO: 更新するコマンドを用意
    field.string :privacy # tootのデフォルト公開度
    field.bool :sensitive # デフォルトでNSFWにするかどうか

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
      API.call(:get, domain, '/api/v1/lists', access_token)
    end

    def lists
      @lists
    end
  end
end
