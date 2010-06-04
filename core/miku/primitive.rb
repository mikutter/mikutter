require 'atom'
require 'error'

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
          raise ArgumentError.new(',@がリスト以外に対して適用されました') if not list.is_a?(List)
          result.concat(list)
        else
          result << n
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
      if(eval(condition)) then
        eval(true_case)
      else
        eval(false_case)
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
      raise ArgumentError('setに与える引数は偶数個にして下さい') if args.size == 1
      key = eval(symtable, key)
      val = eval(symtable, val)
      symtable[key] = val
      return val if args.empty?
      set(symtable, *args)
    end

  end
end
