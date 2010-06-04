require 'node'

module MIKU
  module Atom
    include Node
    def atom
      true
    end

    def miku_eval(symtable=nil)
      self
    end
  end
end
