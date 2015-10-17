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
    self.trap{ |e|
      begin
        notice e
        message = message_generator.call(e) if message_generator
        if(message)
          if(e.is_a?(Net::HTTPResponse))
            Plugin.activity :error, "#{message} (#{e.code} #{e.body})"
          else
            e = 'error' if not e.respond_to?(:to_s)
            Plugin.activity :error, "#{message} (#{e})", exception: e end end
      rescue Exception => inner_error
        error inner_error end
      Deferred.fail(e) } end
end

Delayer.register_remain_hook do
  Thread.main.wakeup
end
