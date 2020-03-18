# -*- coding: utf-8 -*-

require 'serialthread'
require 'lib/weakstorage'

=begin rdoc
画像リソースを扱うModelのためのmix-in。
これをincludeすると、画像データを保存するblobフィールドが追加される。

このmoduleをincludeしたクラスは、必要に応じて _download_routine_ をオーバライドする
=end
module Diva::Model::PhotoMixin
  DOWNLOAD_THREADS = WeakStorage.new(Array, SerialThreadGroup)
  PARALELL_DOWNLOAD_LIMIT_BY_SCHEME_AUTHORITY = 4
  PARTIAL_READ_BYTESIZE = 1024 ** 2

  include Diva::Model::PhotoInterface

  def self.included(klass)
    klass.field.string :blob
  end

  def initialize(*rest)
    super
    @read_count = 0
    @cached = false
    @forget = nil
  end

  # 画像をダウンロードする。
  # partialを指定すると、ダウンロードの進捗があれば、前回呼び出されたときから
  # ダウンロードできた内容を引数に呼び出される。
  # 既にダウンロードが終わっていれば、 _blob_ の戻り値がそのまま渡される。
  # このメソッドは、複数回呼び出されても画像のダウンロードを一度しか行わない。
  # widthとheightは、画像のサイズが複数ある場合に、ダウンロードする画像を決めるために使う。リサイズされるわけではない。
  # ==== Args
  # [width:] ヒントとして提供する幅(px)
  # [height:] ヒントとして提供する高さ(px)
  # [&partial_callback] 現在ダウンロードできたデータの一部(String)
  # ==== Return
  # [Delayer::Deferred::Deferredable] ダウンロードが完了したらselfを引数に呼び出される
  def download(width: nil, height: nil, &partial_callback)      # :yield: part
    increase_read_count
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

  def download_thread
    DOWNLOAD_THREADS[[uri.host, uri.port, uri.scheme == 'https']] ||=
      SerialThreadGroup.new(max_threads: PARALELL_DOWNLOAD_LIMIT_BY_SCHEME_AUTHORITY, deferred: Delayer::Deferred)
  end

  def download!(&partial_callback)
    atomic do
      return download(&partial_callback) unless ready?
      promise = initialize_download(&partial_callback)
      thread = download_thread # 接続中参照させてWeakRefを開放しないようにするんやで（闇運用）
      thread.new(&method(:cache_read_or_download)).next{|success|
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

  def cache_read_or_download
    cache_read_routine || download_routine
  rescue => err
    error err
  end

  def cache_read_routine
    raw = Plugin.filtering(:image_cache, uri.to_s, nil)[1]
    if raw.is_a?(String)
      @buffer = raw.freeze
      atomic{ @partials.each{|c|c.(raw)} }
      true
    end
  end

  def download_routine
    case uri.scheme
    when 'file'
      File.open(uri.path, &method(:download_mainloop))
    when 'http', 'https'
      http_download
    else
      URI.open(uri.to_s, &method(:download_mainloop))
    end
  rescue EOFError
    true
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
      partial = input_stream.readpartial(PARTIAL_READ_BYTESIZE)
      if @buffer
        @buffer << partial
      else
        @buffer = +partial
      end
      atomic{ @partials.each{|c|c.(partial)} }
    end
  end

  def http_download
    http_connection.request_get(uri.path) do |response|
      case response
      when Net::HTTPSuccess
        response.read_body do |partial|
          if @buffer
            @buffer << partial
          else
            @buffer = +partial
          end
          atomic{ @partials.each{|c|c.(partial)} }
        end
      else
        notice "download failed #{response} #{uri}"
      end
    end
  rescue => err
    error err
    raise
  end

  def http_connection
    connection = Net::HTTP.new(uri.host, uri.port)
    connection.use_ssl = uri.scheme == 'https'
    connection
  end

  def initialize_download(&partial_callback)
    @state = :download
    @buffer = nil
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

  # 画像が読まれた回数をインクリメントする。
  # 読み込まれた回数が規定値を超えたら、blobを引数に image_file_cache_photo イベントを発生させて、ストレージにキャッシュさせる
  def increase_read_count
    @read_count += 1
    if !@cached and @read_count >= appear_limit
      @cached = true
      Plugin.call(:image_file_cache_photo, self)
    end
    set_forget_timer
  end

  # blobのメモリキャッシュ消滅タイマーをリセットする。
  # 既に動いているタイマーがあればそれをキャンセルする。
  def set_forget_timer
    @forget.cancel if @forget
    @forget = Reserver.new(forget_time, thread: SerialThread){ forget! }
  end

  # 覚えておりません
  def forget!
    @forget = @state = self.blob = nil
  end

  # キャッシュする出現回数のしきい値を返す
  def appear_limit
    UserConfig[:image_file_cache_appear_limit] || 32
  end

  # 画像をメモリキャッシュする時間(秒)
  # Pixbufが生成されてしまえば基本的にblobにはアクセスされないので、短くて良いと思う
  def forget_time
    (UserConfig[:photo_forget_time] || 60)
  end
end
