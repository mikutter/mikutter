require 'node'

module YamLisp
  include Node

  module Atom
    def atom
      true
    end

    def yamlisp_eval
      self
    end
  end
end
