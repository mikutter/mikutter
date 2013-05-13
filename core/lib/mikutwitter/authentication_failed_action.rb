# -*- coding: utf-8 -*-

require "mikutwitter/basic"
require "mikutwitter/utils"

# OAuthに失敗した時の処理
module MikuTwitter::AuthenticationFailedAction
  class << self
    # Twitterから401が帰ってきた時に、OAuthトークンを取得するためのブロック
    # &callback を登録する。
    # ==== Args
    # [&callback(twitter, method, url, options, res)] Twitter のOAuth トークンが切れた時に呼び出される。以下の引数を取る。
    #   [twitter] 401が返されたリクエストを発行したMikuTwitterのインスタンス
    #   [method] HTTPメソッド。:get, :post, :put, :delete のいずれか
    #   [url] APIのURL
    #   [options] APIの引数
    #   [res] API問い合わせの結果(Net::HTTPResponse)
    # ==== Return
    # 登録したProcオブジェクト
    def regist(&callback)
      @authentication_failed_action = callback end

    # register_authentication_faileded_action で登録されたProcを返す。
    # 何も登録されていない時は、abortするProcを返す。
    # ==== Return
    # 登録されたProcオブジェクト
    def get
      @authentication_failed_action ||= lambda{ |t, m, u, o, r| warn((JSON.parse(r.body)["error"] rescue 'OAuth error')); abort } end

    def lock
      @lock ||= Mutex.new end
  end

  # OAuthトークンを最取得するためのブロックを呼び出す。
  # ==== Args
  # [method] HTTPメソッド。:get, :post, :put, :delete のいずれか
  # [url] APIのURL
  # [options] APIの引数
  # [res] API問い合わせの結果(Net::HTTPResponse)
  def authentication_failed_action(method, url, options, res)
    failed_token, failed_secret = self.a_token, self.a_secret
    MikuTwitter::AuthenticationFailedAction.lock.synchronize{
      if failed_token == self.a_token and failed_secret == self.a_secret
        result = MikuTwitter::AuthenticationFailedAction.get.call(self, method, url, options, res)
        if(result and 2 == result.size)
          self.a_token, self.a_secret = *result
          UserConfig[:twitter_token] = self.a_token
          UserConfig[:twitter_secret] = self.a_secret
          return *result end
      else
        return self.a_token, self.a_secret end } end

end

# デフォルトの認証メソッド: ターミナルでPINコードを入力させる
MikuTwitter::AuthenticationFailedAction.regist{ |service, method, url, options, res|
  begin
    request_token = service.request_oauth_token
    puts "go to #{request_token.authorize_url}"
    print "Authorized number is:"
    $stdout.flush
    access_token = request_token.get_access_token(:oauth_token => request_token.token,
                                                  :oauth_verifier => STDIN.gets.chomp)
    [access_token.token, access_token.secret]
  rescue Timeout::Error, StandardError => e
    error('invalid number')
  end
}

class MikuTwitter; include MikuTwitter::AuthenticationFailedAction end
