# -*- coding: utf-8 -*-

# なんでもDeferred
module Deferredable

  # このDeferredが成功した場合の処理を追加する。
  # 新しいDeferredのインスタンスを返す
  def next(&proc)
    _post(:ok, &proc)
  end
  alias deferred next

  # このDeferredが失敗した場合の処理を追加する。
  # 新しいDeferredのインスタンスを返す
  def trap(&proc)
    _post(:ng, &proc)
  end

  # Deferredを直ちに実行する
  def call(value = nil)
    _call(:ok, value)
  end

  # Deferredを直ちに失敗させる
  def fail(exception = nil)
    _call(:ng, exception)
  end

  # この一連のDeferredをこれ以上実行しない
  def cancel
    @callback = {
      :backtrace => {},
      :ok => lambda{ |x| x },
      :ng => Deferred.method(:fail) }
  end

  def callback
    @callback ||= {
      :backtrace => {},
      :ok => lambda{ |x| x },
      :ng => Deferred.method(:fail) } end

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

  private

  def _call(stat = :ok, value = nil)
    begin
      catch(:__deferredable_success) {
        failed = catch(:__deferredable_fail) {
          n_value = _execute(stat, value)
          if n_value.is_a? Deferredable
            n_value.next{ |result|
              if defined?(@next)
                @next.call(result)
              else
                @next end
            }.trap{ |exception|
              if defined?(@next)
                @next.fail(exception)
              else
                @next end }
          else
            if defined?(@next)
              Delayer.new{ @next.call(n_value) }
            else
              regist_next_call(:ok, n_value) end end
          throw :__deferredable_success
        }
        _fail_action(failed)
      }
    rescue Exception => e
      _fail_action(e) end end

  def _execute(stat, value)
    if Mopt.debug
      r_start = Process.times.utime
      result = callback[stat].call(value)
      if (r_end = Process.times.utime - r_start) > 0.1
        pos = callback[:backtrace][stat].find{|x|not x.include? "deferred"}
        pos = callback[:backtrace][stat].first if not pos
        Plugin.call(:processtime, :deferred, "#{"%.2f" % r_end},#{pos}") end
      result
    else
      callback[stat].call(value) end end

  def _post(kind, &proc)
    @next = Deferred.new(self)
    @next.callback[kind] = proc
    @next.callback[:backtrace][kind] = caller(1)
    if defined?(@next_call_stat) and defined?(@next_call_value)
      @next.__send__({ok: :call, ng: :fail}[@next_call_stat], @next_call_value)
    elsif defined?(@follow) and @follow.nil?
      call end
    @next
  end

  def regist_next_call(stat, value)
    @next_call_stat, @next_call_value = stat, value
    self end

  def _fail_action(e)
    if defined?(@next)
      Delayer.new{ @next.fail(e) }
    else
      regist_next_call(:ng, e) end
  end

end
