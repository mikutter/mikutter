require 'node'
require 'primitive'

module HatsuneLisp
  module List
    include Node

    @@primitive = Primitive.new

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

    def hatsunelisp_car(symtable, node)
      list_check(symtable, node).car
    end

    def hatsunelisp_cdr(symtable, node)
      list_check(symtable, node).cdr
    end

    def list_check(symtable, list)
      raise ArgumentError.new("#{node.inspect} の評価結果 #{list.inspect}の#{parse_caller(caller(2))[2]}を参照しました") if not list.is_a? List
      return list
    end

    def hatsunelisp_eval(symtable=SymbolTable.new)
      operator = hatsunelisp_eval_another(symtable, self.car)
      arguments = self.cdr
      evalarg = lambda{ arguments.map{|node| hatsunelisp_eval_another(symtable, node) } }
      if arguments.car.methods.include?("hatsunelisp_#{operator.to_s}") then
        arguments.car.method("hatsunelisp_#{operator.to_s}").call(symtable, *evalarg.call)
      elsif arguments.car.methods.include?(operator.to_s) then
        arguments.car.method(operator.to_sym).call(*evalarg.call.cdr)
      elsif @@primitive.methods.include?(operator.to_s) then
        @@primitive.method(operator.to_sym).call(symtable, *arguments)
      elsif Kernel.methods.include?(operator.to_s) then
        method(operator.to_sym).call(*evalarg.call)
      end
    end

    def unparse(first=true)
      result = ''
      result << '(' if first
      result << HatsuneLisp.unparse(self.car)
      if(self.cdr.is_a? List) then
        result + ' ' + self.cdr.unparse(false)
      elsif(self.cdr == nil) then
        result + ')'
      else
        result + ' . ' + HatsuneLisp.unparse(self.cdr) + ')'
      end
    end
    
  end
end

require 'cons'
