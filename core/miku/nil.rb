require 'atom'
require 'list'

class NilClass

  include MIKU::Atom
  # include MIKU::List

  def car
    self end

  def cdr
    self end

  def setcar(val)
    MIKU::Cons.new(val, nil) end

  def setcdr(val)
    MIKU::Cons.new(nil, val) end

  # def each(&proc)
  #   nil end

  def mapcarcdr(converter)
    nil end

  def unparse
    'nil' end

  def inspect
    'nil' end

  def miku_eval(symtable=MIKU::SymbolTable.new)
    self end

  def method_missing(name, *args)
    warn 'undefined method #{name} for nil.'
    nil end end
