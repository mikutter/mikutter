# -*- coding: utf-8 -*-
require_relative 'atom'

module MIKU
  class Macro
    include Atom
    def initialize(args, list)
      @args = args
      @list = list
    end

    def macro_expand(*args)
      if not(args.is_a? StaticCode) and args.car.is_a?(StaticCode)
        args.extend(StaticCode).staticcode_copy_info(args.car.staticcode_dump) end
      scope = MIKU::SymbolTable.new.miracle_binding(@args, args)
      # @args.zip(args){ |k, v|
      #   scope[k] = [v] }
      @list.inject(nil){ |last, operator|
        scope[:last] = last
        miku(operator, scope) } end

    def inspect
      "<macro #{@args.inspect} #{@list.inspect}>"
    end
  end
end
