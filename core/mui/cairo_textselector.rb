# -*- coding: utf-8 -*-
require_if_exist 'continuation'
require 'gtk2'

module Gdk
  module TextSelector
    START_TAG_PATTERN = /<\s*\w+.*?>/
    END_TAG_PATTERN = %r{</.*?>}
    ENTITY_ENCODED_PATTERN = /&(?:gt|lt|amp);/
    CHARACTER_PATTERN = /./m
    CHUNK_PATTERN = Regexp.union(START_TAG_PATTERN,
                                 END_TAG_PATTERN,
                                 ENTITY_ENCODED_PATTERN,
                                 CHARACTER_PATTERN)

    START_TAG_PATTERN_EXACT = /\A<\s*\w+.*?>\Z/
    END_TAG_PATTERN_EXACT = %r{\A</.*?>\Z}
    ENTITY_ENCODED_PATTERN_EXACT = /\A&(?:gt|lt|amp);\Z/
    CHARACTER_PATTERN_EXACT = /\A.\Z/m
    NON_TAG_PATTERN_EXACT = Regexp.union(ENTITY_ENCODED_PATTERN_EXACT,
                                         CHARACTER_PATTERN_EXACT)


    def initialize(*args)
      @textselector_pressing = @textselect_start = @textselect_end = nil
      super end

    def textselector_range
      if(@textselect_start and @textselect_end and @textselect_start != @textselect_end)
        first, last = [@textselect_start, @textselect_end].sort
        Range.new(first, last, true) end end

    def textselector_press(index, trail=0)
      @textselector_pressing = true
      before = textselector_range
      @textselect_end = @textselect_start = index + trail
      on_modify if before == textselector_range
      self end

    def textselector_release(index = nil, trail=0)
      textselector_select(index, trail) if index
      @textselector_pressing = false
      self end

    def textselector_unselect
      @textselect_end = @textselect_start = nil
      @textselector_pressing = false
      on_modify
      self end

    def textselector_select(index, trail=0)
      if(@textselector_pressing)
        before = textselector_range
        @textselect_end = index + trail
        on_modify if before == textselector_range end
      self end

    def textselector_markup(styled_text)
      type_strict styled_text => String
      if textselector_range
        markup(styled_text, textselector_range, '<span background="#000000" foreground="#ffffff">', '</span>')
      else
        styled_text end end

    # 文字のインデックス _target_index_ を、 _char_array_ 上で、開始タグと
    # 終了タグの要素を飛ばすと何番目になるかを返す。
    # 例えば:
    #   a = ['f', '<a>', '<b>', 'a', '</b>', 'v', '</a>']
    #   get_aindex(a, 0) # => 0
    #   get_aindex(a, 1) # => 1
    #   get_aindex(a, 2) # => 4
    # _last:_ が真なら、返したインデックスがタグなら、その次を返す。
    #   get_aindex(a, 1) # => 3
    #   get_aindex(a, 2) # => 5
    # ==== Args
    # [char_array] Array 一文字毎に文字列を区切った配列
    # [target_index] _char_array_ 上から開始・終了タグを取り去った配列のインデックス
    # [last:] 真なら、境界の次のインデックスを返す
    # ==== Return
    # Fixnum _char_array_ 上でのindex
    def get_aindex(char_array, target_index, last: false)
      index = 0
      char_array.each_with_index do |char, aindex|
        if last
          return aindex - 1 if index > target_index
        else
          return aindex if index >= target_index
        end
        if NON_TAG_PATTERN_EXACT.match(char)
          index += 1
        end
      end
      char_array.size
    end

    def get_arange(char_array, range)
      Range.new(get_aindex(char_array, range.first, last: true),
                get_aindex(char_array, range.last)) end

    private

    # _char_array_ の中の _range_ の範囲を、タグの対応を壊さないように囲うには
    # どこにタグを入れるべきかをRangeの配列で返す。
    # ==== Args
    # [char_array] Array 一文字毎に文字列を区切った配列
    # [range] Range 囲う予定の場所。このインデックスにタグは含めない
    # ==== Return
    # Array タグで囲むべきインデックス(Range)このインデックスにタグは含まれている
    def arange_split(char_array, range)
      result, stack, arange = [], [], get_arange(char_array, range)
      start = arange.first
      arange.each{ |i|
        case char_array[i]
        when END_TAG_PATTERN_EXACT
          if stack.empty?
            if start <= i-1
              result << Range.new(start, i)
              start = i+1 end
          else
            stack.pop end
        when START_TAG_PATTERN_EXACT
          r, s = result.dup, start
          if not callcc{ |cont| stack.push(cont) }
            result, start = r << Range.new(s, i), i+1 end end }
      if start < arange.last
        stack.pop.call if not stack.empty?
        result << Range.new(start, arange.last) end
      result end

    # _str_ の _range_ の範囲を _start_tag_ と _end_tag_ で囲う。
    # _range_ の間に開始タグや終了タグがあってタグの開始終了の対応が取れなくなる場合、
    # 対応が取れなくなる境界で _end_tag_ を入れて、タグの対応が崩れないようにしつつ
    # _range_ 全体をタグで囲う
    # ==== Args
    # [str] String
    # [range] Range
    # [start_tag] String 挿入する開始タグ
    # [end_tag] String 挿入する終了タグ
    # ==== Return
    # String 加工後の文字列
    def markup(str, range, start_tag, end_tag)
      type_strict str => String
      char_array = str.scan(CHUNK_PATTERN)
      arange_split(char_array.dup, range).reverse_each{ |arange|
        char_array.insert(arange.last, end_tag)
        char_array.insert(arange.first, start_tag)
      }
      char_array.join
    end
  end
end
