module MIKU
  module Node
    def miku_eval_another(symtable, node)
      if(node.is_a? Node) then
        node.miku_eval(symtable)
      else
        node
      end
    end
  end
end
