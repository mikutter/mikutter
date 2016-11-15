# -*- coding: utf-8 -*-

=begin rdoc
画像リソースを扱うModelのためのmix-in。
これをincludeすると、画像データを保存するblobフィールドが追加される。

このmoduleをincludeしたクラスは、必要に応じて _download_routine_ をオーバライドする
=end
module Retriever::PhotoMixin
  def self.included(klass)
    klass.field.string :blob
  end

  # 画像をダウンロードする。
  # partialを指定すると、ダウンロードの進捗があれば、前回呼び出されたときから
  # ダウンロードできた内容を引数に呼び出される。
  # 既にダウンロードが終わっていれば、 _blob_ の戻り値がそのまま渡される。
  # このメソッドは、複数回呼び出されても画像のダウンロードを一度しか行わない。
  # ==== Args
  # [&partial_callback] 現在ダウンロードできたデータの一部(String)
  # ==== Return
  # [Delayer::Deferred::Deferredable] ダウンロードが完了したらselfを引数に呼び出される
  def download(&partial_callback)      # :yield: part
    case @state
    when :complete
      partial_callback.(blob) if block_given?
      Delayer::Deferred.new.next{ self }
    when :download
      append_download_queue(&partial_callback)
    else
      download!(&partial_callback)
    end
  end

  # 画像のダウンロードが終わっていれば真を返す。
  # 真を返す時、 _blob_ には完全な画像の情報が存在している
  def completed?
    @state == :complete
  end

  # 画像をダウロード中なら真
  def downloading?
    @state == :download
  end

  # ダウンロードが始まっていなければ真
  def ready?
    !@state
  end

  def inspect
    if @state == :complete
      "#<#{self.class}: #{uri} (state: #{@state}, #{self.blob.size} bytes cached)>"
    else
      "#<#{self.class}: #{uri} (state: #{@state})>"
    end
  end

  private

  def download!(&partial_callback)
    atomic do
      return download(&partial_callback) unless ready?
      promise = initialize_download(&partial_callback)
      Thread.new(&method(:download_routine)).next{|success|
        if success
          finalize_download_as_success
        else
          Delayer::Deferred.fail false
        end
      }.trap{|exception|
        finalize_download_as_fail(exception)
      }.terminate('error')
      promise
    end
  end

  def append_download_queue(&partial_callback)
    atomic do
      return download(&partial_callback) unless downloading?
      register_partial_callback(partial_callback)
      register_promise
    end
  end

  def register_promise
    promise = Delayer::Deferred.new(true)
    (@promises ||= Set.new) << promise
    promise
  end

  def register_partial_callback(cb)
    @partials ||= Set.new
    if cb
      @partials  << cb
      cb.(@buffer) if !@buffer.empty?
    end
  end

  def download_routine
    begin
      open(uri.to_s) do |is|
        download_mainloop(is)
      end
    rescue EOFError
      true
    end
  end

  # _input_stream_ から、画像をダウンロードし、 _@buffer_ に格納する。
  # このインスタンスの _download_ メソッドが既に呼ばれていて、ブロックが渡されている場合、
  # そのブロックに一定の間隔でダウンロードしたデータを渡す。
  # PhotoMixinをincludeしたクラスでオーバライドされた _download_routine_ から呼ばれることを想定している。
  # ==== Args
  # [input_stream] 画像データがどんどん出てくる IO のインスタンス
  def download_mainloop(input_stream)
    loop do
      Thread.pass
      partial = input_stream.readpartial(1024**2).freeze
      @buffer << partial
      atomic{ @partials.each{|c|c.(partial)} }
    end
  end

  def initialize_download(&partial_callback)
    @state = :download
    @buffer = String.new
    register_partial_callback(partial_callback)
    register_promise
  end

  def finalize_download_as_success
    atomic do
      self.blob = @buffer.freeze
      @state = :complete
      @promises.each{|p| p.call(self) }
      @buffer = @promises = @partials = nil
    end
  end

  def finalize_download_as_fail(exception)
    atomic do
      @state = nil
      @promises.each{|p| p.fail(exception) }
      @buffer = @promises = @partials = nil
    end
  end
end
