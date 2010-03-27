require 'atom'

class Symbol

  include HatsuneLisp::Atom

  def hatsunelisp_eval(symtable=HatsuneLisp::SymbolTable.new)
    symtable[self]
  end
end
