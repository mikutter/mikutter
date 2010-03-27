require 'list'

module HatsuneLisp
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

    def inspect
      "(#{car.inspect}"+(if @cdr.is_a?(Cons) then " #{@cdr.inspect[1..-1]}"
                          elsif @cdr === nil then ')'
                          else " . #{@cdr.inspect})" end)
    end

  end
end
