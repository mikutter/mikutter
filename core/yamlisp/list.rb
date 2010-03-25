require 'node'
require 'primitive'

module YamLisp
  module List
    include Node

    @@primitive = Primitive.new

    def yamlisp_eval
      operator = yamlisp_eval_another(self.car)
      arguments = self.cdr
      if operator.to_s == 'quote' then
        arguments
      else
        evalarg = lambda{ arguments.map{|node| yamlisp_eval_another(node) } }
        if arguments.car.methods.include?("yamlisp_#{operator.to_s}") then
          arguments.car.method("yamlisp_#{operator.to_s}").call(*evalarg.call.cdr)
        elsif arguments.car.methods.include?(operator.to_s) then
          arguments.car.method(operator.to_sym).call(*evalarg.call.cdr)
        elsif @@primitive.methods.include?(operator.to_s) then
          @@primitive.method(operator.to_sym).call(*arguments)
        elsif Kernel.methods.include?(operator.to_s) then
          method(operator.to_sym).call(*evalarg.call)
        end
      end
    end
  end
end

require 'cons'
