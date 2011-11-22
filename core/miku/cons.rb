# -*- coding: utf-8 -*-
require_relative 'list'

module MIKU
  class Cons
    include List
    include Enumerable

    attr_reader(:car, :cdr)

    def self.list(*nodes)
      unless nodes.empty?
        carnode, *cdrnode = *nodes
        Cons.new(carnode, list(*cdrnode))
      end
    end

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

    def to_cons
      self
    end

    def empty?
      false
    end

    def inspect
      "(#{car.inspect}"+(if @cdr.is_a?(Cons) then " #{@cdr.inspect[1..-1]}"
                          elsif @cdr === nil then ')'
                          else " . #{@cdr.inspect})" end)
    end

  end
end
