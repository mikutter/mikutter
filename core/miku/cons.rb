require 'list'

module MIKU
  class Cons
    include List
    include Enumerable

    attr_reader(:car, :cdr)

    def initialize(car, cdr=nil)
      @car = car
      @cdr = cdr
    end

    def setcar(val)
      @car = val
      self
    end

    def setcdr(val)
      @cdr = val
      self
    end

    def each(&proc)
      proc.call @car
      @cdr.each(&proc) if(@cdr.is_a? Enumerable)
    end

    def inspect
      "(#{car.inspect}"+(if @cdr.is_a?(Cons) then " #{@cdr.inspect[1..-1]}"
                          elsif @cdr === nil then ')'
                          else " . #{@cdr.inspect})" end)
    end

  end
end
