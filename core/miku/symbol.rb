require 'atom'

class Symbol

  include MIKU::Atom

  def miku_eval(symtable=MIKU::SymbolTable.new)
    symtable[self].car
  end
end
