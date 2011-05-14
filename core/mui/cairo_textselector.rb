# -*- coding: utf-8 -*-

module Gdk::TextSelector

  def textselector_range
    if(@textselect_start and @textselect_end and @textselect_start != @textselect_end)
      Range.new(@textselect_start, @textselect_end) end end

  def textselector_press(index)
    @textselect_end = @textselect_start = index end

  def textselector_select(index)
    @textselect_end = index end

end
