# -*- coding: utf-8 -*-
require_if_exist 'continuation'
require 'gtk2'

module Gdk
  module TextSelector

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

    private

    def get_aindex(astr, index)
      aindex = 0
      astr.each{ |n|
        if n.size == 1
          index -= 1
        end
        return aindex if(index < 0)
        aindex += 1 }
      astr.size end

    def get_arange(astr, range)
      Range.new(get_aindex(astr, range.first), get_aindex(astr, range.last)) end

    def arange_split(astr, range)
      result, stack, arange = [], [], get_arange(astr, range)
      start = arange.first
      arange.each{ |i|
        case astr[i]
        when /<\/.*?>/
          if stack.empty?
            if start <= i-1
              result << Range.new(start, i)
              start = i+1 end
          else
            stack.pop end
        when /<.*?>/
          r, s = result.dup, start
          if not callcc{ |cont| stack.push(cont) }
            result, start = r << Range.new(s, i), i+1 end end }
      if start < arange.last
        stack.pop.call if not stack.empty?
        result << Range.new(start, arange.last) end
      result end

    def markup(str, range, s, e)
      type_strict str => String
      astr = str.matches(/<.*?>|&(?:gt|lt|amp);|./um)
      arange_split(astr, range).reverse_each{ |arange|
        astr.insert(arange.last, e)
        astr.insert(arange.first, s)
      }
      astr.join
    end
  end
end
