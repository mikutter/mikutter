# -*- coding: utf-8 -*-
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

    def textselector_attr_list(attr_list=Pango::AttrList.new)
      if textselector_range
        bg = ::Pango::AttrBackground.new(*Gdk::MiraclePainter::BLACK)
        fg = ::Pango::AttrForeground.new(*Gdk::MiraclePainter::WHITE)
        bg.start_index = fg.start_index = plain_description[0...textselector_range.first].bytesize
        bg.end_index = fg.end_index = plain_description[0...textselector_range.last].bytesize
        attr_list.insert(bg)
        attr_list.insert(fg)
      end
      attr_list
    end
  end
end
