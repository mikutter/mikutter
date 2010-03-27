require 'node'

module HatsuneLisp
  include Node

  module Atom
    def atom
      true
    end

    def hatsunelisp_eval(symtable=nil)
      self
    end
  end
end
