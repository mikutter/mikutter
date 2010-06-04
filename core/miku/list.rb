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

#     def miku_car(symtable, node)
#       list_check(symtable, node).car
#     end

#     def miku_cdr(symtable, node)
#       list_check(symtable, node).cdr
#     end

    def list_check(symtable, list)
      raise ArgumentError.new("#{node.inspect} の評価結果 #{list.inspect}の#{parse_caller(caller(2))[2]}を参照しました") if not list.is_a? List
      return list
    end

    def miku_eval(symtable=SymbolTable.new)
      operator = get_function(symtable)
      if operator.is_a? Primitive
        operator.call(symtable, *cdr.to_a)
      elsif operator.is_a? Symbol
        call_rubyfunc(operator, *evaluate_args)
      end
    end

    def call_rubyfunc(fn, receiver, *args)
#       if receiver.methods.include?("miku_#{fn}".to_sym)
#         receiver.__send__("miku_#{fn}".to_sym, *args)
#       else
        receiver.__send__(fn, *args)
#       end
    end

    def get_function(symtable)
      if car.is_a? Symbol
        symtable[car].cdr
      else
        miku_eval_another(symtable, car)
      end
    end

    def evaluate_args
      cdr.map{ |n| miku(n) }
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

  class NoMithodError < Exception
  end
end

require 'cons'
