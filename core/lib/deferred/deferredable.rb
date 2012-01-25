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

  def callback
    @callback ||= {
      :backtrace => {},
      :ok => lambda{ |x| x },
      :ng => lambda{ |x| raise x } } end

  private

  def _call(stat = :ok, value = nil)
    begin
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
    rescue => e
      if defined?(@next)
        Delayer.new{ @next.fail(e) }
      else
        regist_next_call(:ng, e) end end end

  def _execute(stat, value)
    callback[stat].call(value) end

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

end
