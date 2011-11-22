# -*- coding: utf-8 -*-
require_relative 'atom'

class Symbol

  include MIKU::Atom

  def miku_eval(symtable=MIKU::SymbolTable.new)
    symtable[self].car
  end

  def unparse(start=true)
    to_s
  end
end
