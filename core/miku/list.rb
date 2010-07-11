require 'node'
require 'primitive'

module MIKU
  module List
    include Node
    include Enumerable

    def [](n)
      nth(n)
    end

    def nth(n)
      result = nthcdr(n)
      if not result.respond_to?(:car)
        raise ExceptionDelegator.new("nthがリストではないもの(#{MIKU.unparse self}の#{n}番目)に対して使われました", TypeError)
      end
      result.car
    end

    def nthcdr(n)
      return self if(n <= 0)
      self.cdr.nthcdr(n-1)
    end

    def list_check(symtable, list)
      raise ArgumentError.new("#{node.inspect} の評価結果 #{list.inspect}の#{parse_caller(caller(2))[2]}を参照しました") if not list.is_a? List
      return list
    end

    def miku_eval(symtable=SymbolTable.new)
      result = nil
      begin
        operator = get_function(symtable)
        if operator.is_a? Primitive
          result = operator.call(symtable, *cdr.to_a)
        elsif defined? operator.call
          result = operator.call(*evaluate_args(symtable))
        elsif operator.is_a? Symbol
          result = call_rubyfunc(operator, *evaluate_args(symtable))
        else
          raise NoMithodError.new(operator, self)
        end
      rescue ExceptionDelegator => e
        e.fire(self)
      end
      if result.is_a? List
        result.extend(StaticCode).staticcode_copy_info(self)
      else
        result end end

    def call_rubyfunc(fn, receiver, *args)
      if receiver.respond_to?(fn)
        begin
          receiver.__send__(fn, *args)
        rescue => e
          p [fn, receiver, *args]
          raise e
        end
      else
        raise NoMithodError.new(fn, self) end end

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
