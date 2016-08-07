# -*- coding: utf-8 -*-

miquire :core, 'environment'

require 'fileutils'
require 'openssl'
require 'securerandom'

class Service
  module SaveData
    ACCOUNT_FILE = File.join(Environment::SETTINGDIR, 'core', 'token').freeze
    ACCOUNT_TMP = (ACCOUNT_FILE + ".write").freeze
    ACCOUNT_CRYPT_KEY_LEN = 16

    extend SaveData
    @@service_lock = Monitor.new

    def key
      key = UserConfig[:account_crypt_key] ||= SecureRandom.random_bytes(ACCOUNT_CRYPT_KEY_LEN)
      key[0, ACCOUNT_CRYPT_KEY_LEN] end

    # 全てのアカウント情報をオブジェクトとして返す
    # ==== Return
    # account_id => {token: ,secret:, ...}
    def accounts
      @account_data ||= @@service_lock.synchronize do
        if FileTest.exist? ACCOUNT_FILE
          File.open(ACCOUNT_FILE, 'rb'.freeze) do |file|
            YAML.load(decrypt(file.read)) end
        else
          # 旧データの引き継ぎ
          result = UserConfig[:accounts]
          if result.is_a? Hash
            # 0.3開発版のデータがある
            account_write result.inject({}){ |hash, item|
              key, value = item
              hash[key] = value.merge(provider: :twitter, slug: key)
              hash }
          elsif UserConfig[:twitter_token] and UserConfig[:twitter_secret]
            # 0.2.x以前のアカウント情報
            account_write({ default: {
                              provider: :twitter,
                              slug: :default,
                              token: UserConfig[:twitter_token],
                              secret: UserConfig[:twitter_secret],
                              user: UserConfig[:verify_credentials] } })
          else
            {} end end end end

    # アカウント情報を返す
    # ==== Args
    # [name] アカウントのキー(Symbol)
    # ==== Return
    # アカウント情報(Hash)
    def account_data(name)
      accounts[name.to_sym] or raise ArgumentError, 'account data `#{name}\' does not exists.' end

    # 新しいアカウントの情報を登録する
    # ==== Args
    # [name] アカウントのキー(Symbol)
    # [options] アカウント情報(Hash)
    # ==== Exceptions
    # ArgumentError name のサービスが既に存在している場合、optionsの情報が足りない場合
    # ==== Return
    # Service
    def account_register(name, options)
      name = name.to_sym
      @@service_lock.synchronize do
        raise ArgumentError, "account #{name} already exists." if accounts.has_key? name
        @account_data = account_write accounts.merge name => {
          provider: (options[:provider] or raise ArgumentError, 'options requires key `provider\'.'),
          slug: (options[:slug] or raise ArgumentError, 'options requires key `slug\'.'),
          token: (options[:token] or raise ArgumentError, 'options requires key `token\'.'),
          secret: (options[:secret] or raise ArgumentError, 'options requires key `secret\'.'),
          user: (options[:user] or raise ArgumentError, 'options requires key `user\'.') } end
      self end

    # アカウント情報を更新する
    # ==== Args
    # [name] アカウントのキー(Symbol)
    # [options] アカウント情報(Hash)
    # ==== Exceptions
    # ArgumentError name のサービスが存在しない場合
    # ==== Return
    # Service
    def account_modify(name, options)
      name = name.to_sym
      @@service_lock.synchronize do
        raise ArgumentError, "account #{name} is not exists." unless accounts.has_key? name
        account_data = accounts[name].merge(options)
        Plugin.call(:image_file_cache_cache, account_data[:user][:profile_image_url])
        @account_data = account_write(accounts.merge(name => account_data)) end
      self end

    # 垢消しの時間だ
    # ==== Args
    # [name]
    # ==== Return
    # Service
    def account_destroy(name)
      name = name.to_sym
      @@service_lock.synchronize do
        to_delete = accounts.dup
        to_delete.delete(name)
        @account_data = account_write(to_delete) end
      self end

    # アカウント情報をファイルに保存する
    def account_write(account_data = @account_data)
      FileUtils.mkdir_p File.dirname(ACCOUNT_FILE)
      File.open(ACCOUNT_TMP, 'wb'.freeze) do |file|
        file << encrypt(YAML.dump(account_data)) end
      FileUtils.mv(ACCOUNT_TMP, ACCOUNT_FILE)
      account_data end

    def encrypt(str)
      cipher = OpenSSL::Cipher.new('bf-ecb').encrypt
      cipher.key_len = ACCOUNT_CRYPT_KEY_LEN
      cipher.key = key
      cipher.update(str) << cipher.final end

    def decrypt(binary_data)
      cipher = OpenSSL::Cipher.new('bf-ecb').decrypt
      cipher.key = key
      str = cipher.update(binary_data) << cipher.final
      str.force_encoding(Encoding::UTF_8)
      str end
  end
end
