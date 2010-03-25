require 'list'

module YamLisp
  class Cons
    include List
    include Enumerable

    attr_accessor(:car, :cdr)

    def initialize(car, cdr)
      @car = car
      @cdr = cdr
    end

    def each
      yield @car
      if(@cdr.is_a? Enumerable) then
        @cdr.each{|*args| yield *args}
      end
    end

  end
end
