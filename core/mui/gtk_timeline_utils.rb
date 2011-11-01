# -*- coding: utf-8 -*-
miquire :lib, 'weakstorage'
miquire :lib, 'uithreadonly'

require 'gtk2'

=begin rdoc
  TimeLineオブジェクト用のメソッド集
以下のメソッドをinclude元に要求する
- block_add
- each
=end
module Gtk::TimeLineUtils

  include UiThreadOnly
  include Enumerable

  def self.included(obj)
    class << obj

      # 存在するタイムラインを全て返す
      def timelines
        @timelines = (@timelines || []).select{ |tl| not tl.destroyed? }.freeze end

      def get_active_mumbles
        Set.new end

      alias :old_new_Ak6FV :new
      def new
        result = old_new_Ak6FV
        @timelines = MIKU::Cons.new(result, @timelines || nil).freeze
        result end

      def wayofopenlink
        @wayofopenlink ||= MIKU::Cons.list([URI.regexp(['http','https']), lambda{ |url, cancel|
                                              Gtk.openurl(url) }].freeze).freeze end

      def addopenway(condition, &open)
        if(type_check(condition => :===, open => :call))
          @wayofopenlink = MIKU::Cons.new([condition, open].freeze, wayofopenlink).freeze
          true end end

      def openurl(url)
        gen_openurl_proc(url).call
        false end

      def gen_openurl_proc(url, way_of_open_link = wayofopenlink)
        way_of_open_link.freeze
        expanded = MessageConverters.expand_url_one(url)
        notice "try to open url '#{url}' expanded '#{expanded}'"
        lambda{
          way_of_open_link.each_with_index{ |way, index|
            condition, open = *way
            if(condition === expanded)
              open.call(url, gen_openurl_proc(url, way_of_open_link[(index+1)..(way_of_open_link.size)]))
              break end } } end

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
      self.block_add_all(Plugin.filtering(:show_filter, message).first)
    else
      m = Plugin.filtering(:show_filter, [message]).first.first
      self.block_add(m) if m.is_a?(Message) end
    self end

  # つぶやきが削除されたときに呼ばれる
  def remove_if_exists_all(msgs)
  end

  # リツイートを受信したときにそれを引数に呼ばれる
  def add_retweets(messages)
  end

  protected

  # 配列で複数のMessageオブジェクトを受け取って適切に処理する。
  # 削除されたつぶやきに関しては _remove_if_exists_all_ を呼び、リツイートだった場合は _add_retweets_ を呼ぶ。
  def block_add_all(messages)
    removes, appends = *messages.partition{ |m| m[:rule] == :destroy }
    remove_if_exists_all(removes)
    retweets, appends = *messages.partition{ |m| m[:retweet] }
    add_retweets(retweets)
    appends.each(&method(:block_add))
  end
end
