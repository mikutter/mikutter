# -*- coding: utf-8 -*-
require_relative 'list'

class Hash
  include MIKU::List

  def car
    to_a.car
  end

  def cdr
    to_a.car
  end

  def terminator
    nil end

  def setcar(val)
    to_a.setcar(val)
  end

  def setcdr(val)
    to_a.setcdr(val)
  end

  def unparse(start=true)
    "#hash(" + map{ |n| "#{n[0]} #{n[1]}" }.join(" ") + ')'
  end

end
