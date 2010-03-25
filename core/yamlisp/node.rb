module YamLisp
  module Node
    def yamlisp_eval_another(node)
      if(node.is_a? Node) then
        node.yamlisp_eval
      else
        node
      end
    end
  end
end
