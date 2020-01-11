# -*- coding: utf-8 -*-
module ::Plugin::Command
  class << self
    extend Gem::Deprecate

    # [in 3.9.0] このメソッドはDeprecateです。
    # [see] https://dev.mikutter.hachune.net/issues/1200
    def [](condition, *other)
      if other.empty?
        const_get(condition.to_sym)
      else
        const_get(condition.to_sym) & self[*other] end end
    deprecate :[], :none, 2020, 01
  end

  # [in 3.9.0] この定数はDeprecateです。
  # [see] https://dev.mikutter.hachune.net/issues/1200
  class Condition
    def initialize(&block)
      @cond = block
      type_strict @cond => :call
    end

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
  deprecate_constant :HasMessage

  # 一つだけMessageが選択されている
  # [in 3.9.0] この定数はDeprecateです。代わりに、condition:には以下のコードを使ってください。
  # ->opt{ opt.messages.size == 1 }
  HasOneMessage = Condition.new{ |opt| opt.messages.size == 1 }
  deprecate_constant :HasOneMessage

  # 選択されているツイートが全てリプライ可能な時。
  # ツイートが選択されていなければ偽
  # [in 3.9.0] この定数はDeprecateです。代わりに、condition:には以下のコードを使ってください。
  # ->opt{ !opt.messages.empty? && compose?(opt.world, to: opt.messages) }
  CanReplyAll = Condition.new{ |opt|
    if not opt.messages.empty?
      current_world, = Plugin.filtering(:world_current, nil)
      Plugin[:command].compose?(current_world, to: opt.messages)
    end
  }
  deprecate_constant :CanReplyAll

  # 選択されているツイートのうち、一つでも現在のアカウントでリツイートできるものがあれば真を返す
  # [in 3.9.0] この定数はDeprecateです。代わりに、condition:には以下のコードを使ってください。
  # ->opt{ opt.messages.any?{|m| share?(opt.world, m) && !shared?(opt.world, m) } }
  CanReTweetAny = Condition.new { |opt|
    current_world, = Plugin.filtering(:world_current, nil)
    opt.messages.lazy.any?{|m|
      Plugin[:command].share?(current_world, m) && !Plugin[:command].shared?(current_world, m)
    }
  }
  deprecate_constant :CanReTweetAny

  # 選択されているツイートが全て、現在のアカウントでリツイート可能な時、真を返す。
  # 既にリツイート済みのものはリツイート不可とみなす。
  # ツイートが選択されていなければ偽
  CanReTweetAll = Condition.new{ |opt|
    current_world, = Plugin.filtering(:world_current, nil)
    !opt.messages.empty? && opt.messages.lazy.all?{|m|
      Plugin[:command].share?(current_world, m) && !Plugin[:command].shared?(current_world, m)
    }
  }
  deprecate_constant :CanReTweetAll

  # 選択されているツイートを、現在のアカウントで全てリツイートしている場合。
  # ツイートが選択されていなければ偽
  # [in 3.9.0] この定数はDeprecateです。代わりに、condition:には以下のコードを使ってください。
  # ->opt{ !opt.messages.empty? && opt.messages.all?{|m| destroy_share?(opt.world, m) } }
  IsReTweetedAll = Condition.new{ |opt|
    current_world, = Plugin.filtering(:world_current, nil)
    !opt.messages.empty? && opt.messages.lazy.all?{|m|
      Plugin[:command].destroy_share?(current_world, m)
    }
  }
  deprecate_constant :IsReTweetedAll

  # 選択されているツイートのうち、一つでも現在のアカウントでふぁぼれるものがあれば真を返す
  # [in 3.9.0] この定数はDeprecateです。代わりに、condition:には以下のコードを使ってください。
  # ->opt{ opt.messages.any?{|m| favorite?(opt.world, m) && favorited?(opt.world, m) } }
  CanFavoriteAny = Condition.new { |opt|
    current_world, = Plugin.filtering(:world_current, nil)
    opt.messages.any?{|m|
      Plugin[:command].favorite?(current_world, m) && !Plugin[:command].favorited?(current_world, m)
    }
  }
  deprecate_constant :CanFavoriteAny

  # 選択されているツイートが全て、現在のアカウントでお気に入りに追加可能な時、真を返す。
  # 既にお気に入りに追加済みのものはお気に入りに追加不可とみなす。
  # ツイートが選択されていなければ偽
  CanFavoriteAll = Condition.new{ |opt|
    current_world, = Plugin.filtering(:world_current, nil)
    !opt.messages.empty? and opt.messages.all?{|m|
      Plugin[:command].favorite?(current_world, m)
    }
  }
  deprecate_constant :CanFavoriteAll

  # 選択されているツイートを、現在のアカウントで全てお気に入りに追加している場合。
  # ツイートが選択されていなければ偽
  # [in 3.9.0] この定数はDeprecateです。代わりに、condition:には以下のコードを使ってください。
  # ->opt{ !opt.messages.empty? && opt.messages.all?{|m| Plugin[:command].unfavorite?(opt.world, m) } }
  IsFavoritedAll = Condition.new{ |opt|
    current_world, = Plugin.filtering(:world_current, nil)
    !opt.messages.empty? and opt.messages.all?{|m|
      Plugin[:command].unfavorite?(current_world, m)
    }
  }
  deprecate_constant :IsFavoritedAll

  # 選択しているのが全て自分のツイートの時
  # [in 3.9.0] この定数はDeprecateです。代わりに、condition:には以下のコードを使ってください。
  # ->opt{ !opt.messages.empty? && opt.messages.all?{|m| m.from_me?(opt.world) } }
  IsMyMessageAll = Condition.new{ |opt|
    current_world, = Plugin.filtering(:world_current, nil)
    not opt.messages.empty? and opt.messages.all?{|m| m.from_me?(current_world) }
  }
  deprecate_constant :IsMyMessageAll

  # TL上のテキストが一文字でも選択されている
  # [in 3.9.0] この定数はDeprecateです。代わりに、condition:には以下のコードを使ってください。
  # ->opt{ opt.widget.selected_text(opt.messages.first) }
  TimelineTextSelected = Condition.new{ |opt| opt.widget.selected_text(opt.messages.first) }
  deprecate_constant :TimelineTextSelected

  HasParmaLinkAll = Condition.new{ |opt|
    not opt.messages.empty? and opt.messages.all? { |m| m.perma_link } }
  deprecate_constant :HasParmaLinkAll

  # ==== postbox ロール

  # 編集可能状態（入力中：グレーアウトしてない時）
  # [in 3.9.0] この定数はDeprecateです。代わりに、condition:には以下のコードを使ってください。
  # ->opt{ opt.widget.editable? }
  Editable = Condition.new{ |opt| opt.widget.editable? }
  deprecate_constant :Editable

  deprecate_constant :Condition
end



