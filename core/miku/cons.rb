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
      self.class.new(val, @cdr)
    end

    def setcdr(val)
      self.class.new(@car, val)
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
