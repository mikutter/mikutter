# -*- coding: utf-8 -*-

require_relative 'keep'
require 'instance_storage'

# miquire :core, 'environment', 'configloader', 'userconfig'
# miquire :lib, "mikutwitter", 'reserver', 'delayer'

=begin rdoc
Twitter APIとmikutterプラグインのインターフェイス
=end
module Service
  extend Enumerable

  class << self

    # 存在するServiceオブジェクトを全て返す。
    # つまり、投稿権限のある「自分」のアカウントを全て返す。
    # ==== Return
    # [Array] アカウントを示すDiva::Modelを各要素に持った配列。
    def instances
      results, = Plugin.filtering(:accounts, Array.new)
      results
    end
    alias services instances

    # Service.instances.eachと同じ
    def each(*args, &proc)
      instances.each(*args, &proc) end

    # 現在アクティブになっているサービスを返す。
    # 基本的に、あるアクションはこれが返すアカウントに対して行われなければならない。
    # ==== Return
    # アクティブなアカウントに対応するModelか、存在しない場合はnil
    def primary
      account, = Plugin.filtering(:account_current, nil)
      account
    end
    alias primary_service primary

    # 現在アクティブになっているサービスを返す。
    # Service.primary とちがって、サービスが一つも登録されていない時、例外を発生させる。
    # ==== Exceptions
    # Plugin::Account::NotExistError :: (選択されている)Serviceが存在しない
    # ==== Return
    # アクティブなService
    def primary!
      result = primary
      raise Plugin::Account::NotExistError, 'Account does not exists.' unless result
      result
    end

    def set_primary(service)
      Plugin.call(:account_change_current, service)
      self
    end

    # 新しくサービスを認証する
    def add_service(token, secret)
      type_strict token => String, secret => String

      twitter = MikuTwitter.new
      twitter.consumer_key = Environment::TWITTER_CONSUMER_KEY
      twitter.consumer_secret = Environment::TWITTER_CONSUMER_SECRET
      twitter.a_token = token
      twitter.a_secret = secret

      (twitter/:account/:verify_credentials).user.next { |user|
        id = "twitter#{user.id}".to_sym
        Service::SaveData.account_register id, {
          provider: :twitter,
          slug: id,
          token: token,
          secret: secret,
          user: {
            id: user[:id],
            idname: user[:idname],
            name: user[:name],
            profile_image_url: user[:profile_image_url] } }
        service = Service[id]
        Plugin.call(:service_registered, service)
        service
      }
    end

    def destroy(service)
      Plugin.call(:account_destroy, service)
    end
    def remove_service(service)
      destroy(service) end
  end

  # # プラグインには、必要なときにはこのインスタンスが渡るようになっているので、インスタンスを
  # # 新たに作る必要はない
  # def initialize(name)
  #   super
  #   account = Service::SaveData.account_data name
  #   @twitter = MikuTwitter.new
  #   @twitter.consumer_key = Environment::TWITTER_CONSUMER_KEY
  #   @twitter.consumer_secret = Environment::TWITTER_CONSUMER_SECRET
  #   @twitter.a_token = account[:token]
  #   @twitter.a_secret = account[:secret]
  #   user_initialize
  # end

  # # アクセストークンとアクセスキーを再設定する
  # def set_token_secret(token, secret)
  #   Service::SaveData.account_modify name, {token: token, secret: secret}
  #   @twitter.a_token = token
  #   @twitter.a_secret = secret
  #   self
  # end

  # # 自分のUserを返す。初回はサービスに問い合せてそれを返す。
  # def user_obj
  #   @user_obj end
  # alias to_user user_obj

  # # 自分のユーザ名を返す。初回はサービスに問い合せてそれを返す。
  # def user
  #   @user_obj[:idname] end
  # alias :idname :user

  # # userと同じだが、サービスに問い合わせずにnilを返すのでブロッキングが発生しない
  # def user_by_cache
  #   @user_idname end

  # # selfを返す
  # def service
  #   self end
end

Post = Service
