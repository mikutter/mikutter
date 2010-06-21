require 'node'
require 'primitive'

module MIKU
  module List
    include Node

    def [](n)
      nth(n)
    end

    def nth(n)
      nthcdr(n).car
    end

    def nthcdr(n)
      return self if(n <= 0)
      self.cdr[n-1]
    end

    def list_check(symtable, list)
      raise ArgumentError.new("#{node.inspect} の評価結果 #{list.inspect}の#{parse_caller(caller(2))[2]}を参照しました") if not list.is_a? List
      return list
    end

    def miku_eval(symtable=SymbolTable.new)
      operator = get_function(symtable)
      if operator.is_a? Primitive
        operator.call(symtable, *cdr.to_a)
      elsif defined? operator.call
        operator.call(*evaluate_args(symtable))
      elsif operator.is_a? Symbol
        call_rubyfunc(operator, *evaluate_args(symtable))
      else
        raise NoMithodError.new()
      end
    end

    def call_rubyfunc(fn, receiver, *args)
      receiver.__send__(fn, *args)
    end

    def get_function(symtable)
      if car.is_a? Symbol
        symtable[car].cdr or car
      else
        miku_eval_another(symtable, car)
      end
    end

    def evaluate_args(scope)
      cdr.map{|node| miku(node, scope)}
    end

    def unparse
      '(' + _unparse
    end

    def _unparse
      result = ''
      result << MIKU.unparse(self.car)
      if(self.cdr == nil)
        result + ')'
      elsif(self.cdr.is_a? List)
        result + ' ' + self.cdr._unparse
      else
        result + ' . ' + MIKU.unparse(self.cdr) + ')'
      end
    end
  end

end

require 'cons'
