# -*- coding: utf-8 -*-

require "delayer"
require "delayer/deferred"

Delayer.default = Delayer.generate_class(priority: [:ui_response,
                                                    :routine_active,
                                                    :ui_passive,
                                                    :routine_passive,
                                                    :ui_favorited],
                                         default: :routine_passive,
                                         expire: 0.02)

Deferred = Delayer::Deferred::Deferred

module Delayer::Deferred::Deferredable
  # エラーをキャッチして、うまい具合にmikutterに表示する。
  # このあとにdeferredをくっつけることもできるが、基本的にはdeferredチェインの終了の時に使う。
  # なお、terminateは受け取ったエラーを再度発生させるので、terminateでエラーを処理した後に特別なエラー処理を挟むこともできる
  # ==== Args
  # [message] 表示用エラーメッセージ。偽ならエラーはユーザに表示しない（コンソールのみ）
  # [&message_generator] エラーを引数に呼ばれる。 _message_ を返す
  # ==== Return
  # Deferred
  def terminate(message = nil, &message_generator)
    self.trap{|exception|
      message = message_generator.call(exception) if message_generator
      case exception
      when MikuTwitter::RateLimitError
        Deferred.fail(exception)
      when MikuTwitter::TwitterError
        notice "#{exception.class}: #{exception.to_s}"
        if message
          Plugin.activity :error, "#{message} (#{exception.message} #{exception.code})", exception: exception end
      else
        begin
          notice exception
          if(message)
            if(exception.is_a?(Net::HTTPResponse))
              Plugin.activity :error, "#{message} (#{exception.code} #{exception.body})"
            else
              exception = 'error' if not exception.respond_to?(:to_s)
              Plugin.activity :error, "#{message} (#{exception})", exception: exception end end
        rescue Exception => inner_error
          error inner_error end end
      Deferred.fail(exception) } end
end

Delayer.register_remain_hook do
  Thread.main.wakeup
end
