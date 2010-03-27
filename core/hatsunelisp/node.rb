module HatsuneLisp
  module Node
    def hatsunelisp_eval_another(symtable, node)
      if(node.is_a? Node) then
        node.hatsunelisp_eval(symtable)
      else
        node
      end
    end
  end
end
