require 'atom'
require 'list'

class NilClass

  include HatsuneLisp::Atom
  include HatsuneLisp::List

  def car
    self end

  def cdr
    self end

  def setcar(val)
    HatsuneLisp::Cons.new(val, nil) end

  def setcdr(val)
    HatsuneLisp::Cons.new(nil, val) end

  def each(&proc)
    nil end

  def unparse
    self end

  def inspect
    'nil' end

  def hatsunelisp_eval(symtable=HatsuneLisp::SymbolTable.new)
    self end end
