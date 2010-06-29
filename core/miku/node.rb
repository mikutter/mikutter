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

  module StaticCode
    attr_accessor :staticcode_line, :staticcode_file

    def staticcode_copy_info(src)
      @staticcode_line = src.staticcode_line
      @staticcode_file = src.staticcode_file
      self end

    def self.extended(obj)
      obj.staticcode_line = 1
      obj.staticcode_file = 'runtime-code' end end

end
