# -*- coding: utf-8 -*-
miquire :lib, 'weakstorage'

require 'gtk2'

=begin rdoc
  TimeLineオブジェクト用のメソッド集
以下のメソッドをinclude元に要求する
- block_add
- each
=end
module Gtk::TimeLineUtils
  include Enumerable
  def self.included(obj)
    class << obj

      # 存在するタイムラインを全て返す
      def timelines
        @timelines = @timelines.select{ |tl| not tl.destroyed? } end

      alias :old_new :new
      def new
        result = old_new
        (@timelines ||= WeakSet.new) << result
        result end

      # IntelligentTextviewの中で、正規表現 _reg_ に一致する文字列がクリックされたとき、Procを呼ぶようにする
      def addlinkrule(reg, &proc)
      end

      def addwidgetrule(reg, &proc)
      end end end

  # このタイムラインに保存できるメッセージの最大数。超えれば古いものから捨てられる。
  attr_accessor :timeline_max

  # _message_ が新たに _user_ のお気に入りに追加された時に呼ばれる
  def favorite(user, message)
    mumble = get_mumble_by(message)
    mumble.on_favorited(user) if mumble
    self
  end

  # _message_ が _user_ のお気に入りから削除された時に呼ばれる
  def unfavorite(user, message)
    mumble = get_mumble_by(message)
    mumble.on_unfavorited(user) if mumble
    self
  end

  # _message_ が更新された時に呼ばれる
  def modified(message)
  end

  # _message_ を追加する。配列で複数のMessageオブジェクトを渡すこともできる。
  def add(message)
    if message.is_a?(Enumerable) then
      self.block_add_all(message)
    else
      self.block_add(message) end
    self end

  # 配列で複数のMessageオブジェクトを受け取って適切に処理する。
  # 削除されたつぶやきに関しては _remove_if_exists_all_ を呼び、リツイートだった場合は _add_retweets_ を呼ぶ。
  def block_add_all(messages)
    removes, appends = *messages.partition{ |m| m[:rule] == :destroy }
    remove_if_exists_all(removes)
    retweets, appends = *messages.partition{ |m| m[:retweet] }
    add_retweets(retweets)
    appends.each(&method(:block_add))
  end

  # つぶやきが削除されたときに呼ばれる
  def remove_if_exists_all(msgs)
  end

  # リツイートを受信したときにそれを引数に呼ばれる
  def add_retweets(messages)
  end
end
