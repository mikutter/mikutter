require 'node'

module HatsuneLisp
  module Atom
    include Node
    def atom
      true
    end

    def hatsunelisp_eval(symtable=nil)
      self
    end
  end
end
