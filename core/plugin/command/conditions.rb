# -*- coding: utf-8 -*-
module ::Plugin::Command
  class << self
    def [](condition, *other)
      if other.empty?
        const_get(condition.to_sym)
      else
        const_get(condition.to_sym) & self[*other] end end
  end

  class Condition
    def initialize
      @cond = Proc.new
      type_strict @cond => :call end

    def &(follow)
      type_strict follow => :call
      Condition.new{ |opt| call(opt) && follow.call(opt) } end

    def |(follow)
      type_strict follow => :call
      Condition.new{ |opt| call(opt) || follow.call(opt) } end

    def call(opt)
      @cond.call(opt) end
    alias === call
    alias [] call
  end

  # ==== timeline ロールの条件

  # 一つでもMessageが選択されている
  HasMessage = Condition.new{ |opt| not opt.messages.empty? }

  # 一つだけMessageが選択されている
  HasOneMessage = Condition.new{ |opt| opt.messages.size == 1 }

  # 選択されているツイートが全てリプライ可能な時。
  # ツイートが選択されていなければ偽
  CanReplyAll = Condition.new{ |opt|
    not opt.messages.empty? and opt.messages.all? &:repliable? }

  # 選択されているツイートが全てリツイート可能な時。
  # ツイートが選択されていなければ偽
  CanReTweetAll = Condition.new{ |opt|
    not opt.messages.empty? and opt.messages.all? { |m|
      m.retweetable? and not m.retweeted_by_me? } }

  # 選択されているツイートが全てに対してリツイートしている場合。
  # ツイートが選択されていなければ偽
  IsReTweetedAll = Condition.new{ |opt|
    not opt.messages.empty? and opt.messages.all? { |m|
      m.retweetable? and m.retweeted_by_me? } }

  # 選択されているツイートが全てお気に入りに追加可能な時。
  # ツイートが選択されていなければ偽
  CanFavoriteAll = Condition.new{ |opt|
    not opt.messages.empty? and opt.messages.all? { |m|
      m.favoritable? and not m.favorited_by_me? } }

  # 選択されているツイートが全てが既にお気に入りに追加されている場合。
  # ツイートが選択されていなければ偽
  IsFavoritedAll = Condition.new{ |opt|
    not opt.messages.empty? and opt.messages.all? { |m|
      m.favoritable? and m.favorited_by_me? } }

  # 選択しているのが全て自分のツイートの時
  IsMyMessageAll = Condition.new{ |opt|
    not opt.messages.empty? and opt.messages.all?(&:from_me?) }

  # TL上のテキストが一文字でも選択されている
  TimelineTextSelected = Condition.new{ |opt| opt.widget.selected_text(opt.messages.first) }

  # ==== postbox ロール

  # 編集可能状態（入力中：グレーアウトしてない時）
  Editable = Condition.new{ |opt| opt.widget.editable? }

end
