require 'node'

module YamLisp
  class Primitive
    include Node

    def cons(head, tail)
      Cons.new(eval(head), eval(tail))
    end

    def eval(node)
      yamlisp_eval_another(node)
    end

    def eq(a, b)
      eval(a) == eval(b)
    end

    def if(condition, true_case, false_case)
      if(eval(condition)) then
        eval(true_case)
      else
        eval(false_case)
      end
    end

  end
end
