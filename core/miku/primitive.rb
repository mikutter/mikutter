# -*- coding: utf-8 -*-
require_relative 'atom'
require_relative 'error'
require_relative 'macro'

module MIKU
  class Primitive
    include Atom

    def initialize(func)
      @func = func.to_sym
    end

    def call(*args)
      send(@func, *args)
    end

    def self.injecting_method(name, method = nil)
      method = name unless method
      define_method(name){ |symtable, *objects|
        unless objects.empty?
          first, *rest = *objects
          rest.inject(eval(symtable, first)){|a, b|
            a.__send__(method, eval(symtable, b)) } end } end

    def self.consing_method(name, method = nil)
      method = name unless method
      define_method(name){ |symtable, *objects|
        unless objects.empty?
          objects.map{ |x| eval(symtable, x) }.enum_for(:each_cons, 2).all?{ |a|
            a[0].__send__(method, a[1]) } end } end

    injecting_method(:+)
    injecting_method(:-)
    injecting_method(:*)
    injecting_method(:/)

    consing_method(:<)
    consing_method(:>)
    consing_method(:<=)
    consing_method(:>=)
    consing_method(:eq, :equal?)
    consing_method(:eql, :==)
    consing_method(:equal, :===)

    def backquote(symtable, val)
      result = []
      val.each{|n|
        if not n.is_a?(List) then
          result << n
        elsif n.car == :comma then
          result << eval(symtable, n[1])
        elsif n.car == :comma_at then
          list = eval(symtable, n[1])
          raise ExceptionDelegator.new(',@がリスト以外に対して適用されました', ArgumentError) if not list.is_a?(List)
          result.concat(list) if list
        else
          result << backquote(symtable, n)
        end
      }
      result
    end

    def cons(symtable, head, tail)
      Cons.new(eval(symtable, head), eval(symtable, tail))
    end

    def eval(symtable, node)
      miku_eval_another(symtable, node)
    end

    def _not(symtable, sexp)
      not eval(symtable, sexp) end

    def if(symtable, condition, true_case, false_case = nil)
      if(eval(symtable, condition)) then
        eval(symtable, true_case)
      else
        eval(symtable, false_case)
      end
    end

    def list(symtable, *args)
      args.map{|n| eval(symtable, n) }.to_cons
    end

    def listp(symtable, val)
      eval(symtable, val).is_a?(List)
    end

    def quote(symtable, val)
      val
    end

    def set(symtable, key, val, *args)
      raise ExceptionDelegator.new('setに与える引数は偶数個にして下さい', ArgumentError) if args.size == 1
      key = eval(symtable, key)
      val = eval(symtable, val)
      symtable.set(key, val)
      return val if args.empty?
      set(symtable, *args)
    end

    def defun(symtable, key, val, *args)
      raise ExceptionDelegator.new('defunに与える引数は偶数個にして下さい', ArgumentError) if args.size == 1
      key = eval(symtable, key)
      val = eval(symtable, val)
      symtable.defun(key, val)
      return val if args.empty?
      defun(symtable, *args)
    end

    def function(symtable, symbol)
      if symbol.is_a? Symbol
        symtable[symbol].cdr
      else
        symbol end end

    def macro(symtable, alist, *body)
      Macro.new(alist, body)
    end

    def macro_expand_all(symtable, sexp)
      if sexp.is_a? List
        expanded = macro_expand(symtable, sexp)
        if expanded.is_a? List
          expanded.map{|node|
            macro_expand_all_ne(symtable, node) }
        else
          expanded end
      else
        sexp end end

    def macro_expand_all_ne(symtable, sexp)
      if sexp.is_a? List
        expanded = macro_expand_ne(symtable, sexp)
        if expanded.is_a? List
          expanded.map{|node|
            macro_expand_all_ne(symtable, node) }
        else
          expanded end
      else
        sexp end end

    def macro_expand_ne(symtable, sexp)
      if sexp.is_a? List
        macro = if(sexp.car.is_a? Symbol)
                  symtable[sexp.car].cdr
                else
                  eval(symtable, sexp.car) end
        if macro.is_a?(Macro)
          macro.macro_expand(*sexp.cdr.to_a) end
      else
        sexp end end

    def macro_expand(symtable, sexp)
      macro_expand_ne(symtable, eval(symtable, sexp)) end

    def negi(parenttable, alist, *body)
      # body = body.map{ |node| macro_expand(parenttable, node) }
      lambda{ |*args|
        symtable = parenttable.miracle_binding(alist, args)
        body.inject(nil){ |last, operator|
          eval(symtable, operator) } } end

    def require_runtime_library(symtable, filename)
      require eval(symtable, filename)
    end

  end
end
