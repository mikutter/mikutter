# -*- coding: utf-8 -*-
require "mikutwitter/basic"

class MikuTwitter::StreamingFailedActions

  attr_reader :last_code, :wait_time, :fail_count

  def initialize(name, plugin)
    @name = name
    @plugin = plugin
    @last_code = '200'.freeze
    @wait_time = @fail_count = 0
  end

  def notify(e)
    if e.respond_to?(:code)
      if e.code != @last_code
        case e.code
        when '200'.freeze
          success
        when '401'.freeze         # unauthorized
          client_bug e
        when '403'.freeze         # forbidden
          client_bug e
        when '404'.freeze         # unknown
          client_bug e
        when '406'.freeze         # not accepptable
          client_bug e
        when '413'.freeze         # too long
          client_bug e
        when '416'.freeze         # range unacceptable
          client_bug e
        when '420'.freeze         # rate limited
          rate_limit e
        when '500'.freeze         # server internal error
          flying_whale e
        when '503'.freeze         # service overloaded
          flying_whale e
        end
      end
      httperror
      @last_code = e.code
    elsif e.is_a?(Exception) or e.is_a?(Thread)
      tcperror
    end
  end

  # 接続できた時の処理
  # ==== Args
  # [e] レスポンス(Net::HTTPResponse)
  def success
    title = "#{@name}: 接続できました。"
    desc = ""
    if @last_code[0] == '5'.freeze
      desc = "まだTwitterサーバが完全には復旧していないかも知れません。\n"+
        "Twitterサーバの情報は以下のWebページで確認することができます。\nhttps://dev.twitter.com/status"
    elsif @last_code == '420'.freeze
      desc = "規制解除されたみたいですね。よかったですね。" end
    if @last_code != '200'.freeze
      @plugin.activity(:status, title,
                       description: title + "\n" + desc) end
    @wait_time = @fail_count = 0
    @last_code = '200'.freeze
  end

  # こちらの問題が原因でTwitterサーバからエラーが返って来ている場合の処理。
  # ただし、過去には何度もサーバ側の不具合で4xx系のエラーが返って来ていたことが
  # あったのであまり宛てにするべきではない
  # ==== Args
  # [e] レスポンス(Net::HTTPResponse)
  def client_bug(e)
    title = "#{@name}: 切断されました。再接続します"
    @plugin.activity(:status, title,
                     description: "#{title}\n接続できませんでした(#{get_error_str(e)})") end

  # 規制された時の処理
  # ==== Args
  # [e] レスポンス(Net::HTTPResponse)
  def rate_limit(e)
    title = "#{@name}: API実行回数制限を超えました。しばらくしてから自動的に再接続します。"
    @plugin.activity(:status, title,
                     description: "#{title}\n複数のTwitterクライアントを起動している場合は、それらを終了してください。\n(#{get_error_str(e)})") end

  # サーバエラー・過負荷時の処理
  # ==== Args
  # [e] レスポンス(Net::HTTPResponse)
  def flying_whale(e)
    title = "#{@name}: 切断されました。しばらくしてから自動的に再接続します。"
    @plugin.activity(:status, title,
                     description: "#{title}\nTwitterサーバが応答しません。また何かあったのでしょう(#{get_error_str(e)})。\n"+
                     "Twitterサーバの情報は以下のWebページで確認することができます。\nhttps://dev.twitter.com/status") end

  private

  def get_error_str(e)
    result = ""
    result += e.code if e.respond_to? :code
    result += " "+e.body.chomp if e.respond_to? :body
    return e.to_s if result.empty?
    result end

  def tcperror
    @fail_count += 1
    if 1 < @fail_count
      @wait_time += 0.25
      if @wait_time > 16
        @wait_time = 16 end end end

  def httperror
    @fail_count += 1
    if 1 < @fail_count
      if 2 == @fail_count
        @wait_time = 10
      else
        @wait_time *= 2
        if @wait_time > 240
          @wait_time = 240 end end end end
end
