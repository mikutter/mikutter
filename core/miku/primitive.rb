require 'atom'
require 'error'
require 'macro'

module MIKU
  class Primitive
    include Atom

    def initialize(func)
      @func = func.to_sym
    end

    def call(*args)
      send(@func, *args)
    end

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

    def eq(symtable, a, b)
      eval(symtable, a) == eval(symtable, b)
    end

    def if(symtable, condition, true_case, false_case)
      if(eval(symtable, condition)) then
        eval(symtable, true_case)
      else
        eval(symtable, false_case)
      end
    end

    def list(symtable, *args)
      args.map{|n| eval(symtable, n) }
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
      setf(symtable, *args)
    end

    def function(symtable, symbol)
      if symbol.is_a? Symbol
        symtable[symbol].cdr
      else
        symbol end end

    def macro_expand(symtable, body)
      self.class.macro_expand(symtable, body) end

    def self.macro_expand(symtable, body)
      if body.is_a? List
        macro = body.get_function(symtable)
        return do_macro_expand(symtable.ancestor, body) if macro.is_a? MIKU::Macro
      end
      body end

    def self.do_macro_expand(symtable, body)
      body.get_function(symtable).call(*body.cdr.to_a) end


    def macro(parenttable, alist, *body)
      negi(parenttable, alist, *body).extend(MIKU::Macro) end

    def negi(parenttable, alist, *body)
      body = body.map{ |node| macro_expand(parenttable, node) }
      lambda{ |*args|
        symtable = parenttable.miracle_binding(alist, args)
        body.inject(nil){ |last, operator|
          symtable[:last] = last
          eval(symtable, operator) } } end

  end
end
