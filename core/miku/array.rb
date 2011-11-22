# -*- coding: utf-8 -*-
require_relative 'list'

class Array
  include MIKU::List

  def car
    self.first
  end

  def cdr
    result = self[1..self.size]
    if is_a?(MIKU::StaticCode)
      result.extend(MIKU::StaticCode).staticcode_copy_info(staticcode_dump) end
    result unless result.empty? end

  def terminator
    nil end

  def setcar(val)
    result = val.clone
    result[0] = val
    result.freeze
  end

  def setcdr(val)
    MIKU::Cons.new(self.car, val)
  end

  def unparse(start=true)
    result = ''
    result = '(' if start
    result + self.map{ |n| MIKU.unparse(n) }.join(' ') + ')'
  end

end
