# -*- coding: utf-8 -*-

module Gdk::TextSelector

  def textselector_range
    if(@textselect_start and @textselect_end and @textselect_start != @textselect_end)
      Range.new(*[@textselect_start, @textselect_end].sort) end end

  def textselector_press(index)
    @textselector_pressing = true
    before = textselector_range
    @textselect_end = @textselect_start = index
    on_modify if before == textselector_range
    self
  end

  def textselector_release(index = nil)
    textselector_select(index) if index
    @textselector_pressing = false
  end

  def textselector_unselect
    @textselect_end = @textselect_start = nil
    @textselector_pressing = false
    on_modify
  end

  def textselector_select(index)
    if(@textselector_pressing)
      before = textselector_range
      @textselect_end = index
      on_modify if before == textselector_range end end

  def textselector_markup(styled_text)
    if textselector_range
      markup(styled_text, textselector_range, '<span background="#000000" foreground="#ffffff">', '</span>')
    else
      styled_text end end

  private

  def get_aindex(astr, index)
    aindex = 0
    astr.each{ |n|
      if n.strsize == 1
        index -= 1
      end
      return aindex if(index < 0)
      aindex += 1
    }
  end

  def get_arange(astr, range)
    Range.new(get_aindex(astr, range.first), get_aindex(astr, range.last))
  end

  def arange_split(astr, range)
    result = []
    arange = get_arange(astr, range)
    start = arange.first
    level = 0
    arange.each{ |i|
      [i, level] # => 
      case astr[i]
      when /<\/.*?>/
        if level <= 0
          [i, start] # => 
          if start <= i-1
            [start, i] # => 
            result << Range.new(start, i)
            start = i+1 end
        else
          level -= 1 end
      when /<.*?>/
        level += 1 end
    }
    if start < arange.last
      result << Range.new(start, arange.last) end
    result
  end

  def markup(str, range, s, e)
    astr = str.matches(/<.*?>|./)
    astr # => 
    aranges = arange_split(astr, range) # => 
    aranges.reverse_each{ |arange|
      astr.insert(arange.last, e)
      astr.insert(arange.first, s)
    }
    astr.join
  end
end
# ~> -:3: uninitialized constant Gdk (NameError)
