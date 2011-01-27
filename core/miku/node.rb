# -*- coding: utf-8 -*-


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
      if src.is_a? Array
      @staticcode_line = src[0]
      @staticcode_file = src[1]
      else
        @staticcode_line = src.staticcode_line
        @staticcode_file = src.staticcode_file end
      self end

    def staticcode_dump
      [@staticcode_file, @staticcode_line] end

    def self.extended(obj)
      obj.staticcode_line = 1
      obj.staticcode_file = 'runtime-code' end end

end 
