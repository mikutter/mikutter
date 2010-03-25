require 'list'

class Array
  include YamLisp::List

  def car
    self.first
  end

  def cdr
    self[1..self.size]
  end

end
