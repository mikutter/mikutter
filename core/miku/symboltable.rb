require 'error'

module MIKU
  class SymbolTable < Hash
    def initialize(parent = SymbolTable.defaults)
      super(){ |this, key| parent[key.to_sym] }
    end

    def []=(key, val)
      if not(key.is_a?(Symbol)) then
        raise TypeError.new("#{key.class}(#{key.inspect})に値を代入しようとしました")
      end
      super(key, self[key.to_sym].setcar(val))
    end

    def self.defsform(fn=nil, *other)
      return [] if fn == nil
      [fn , Cons.new(nil, Primitive.new(fn))] + defsform(*other)
    end

    def self.defun(fn=nil, *other)
      return [] if fn == nil
      [fn , Cons.new(nil, fn)] + defun(*other)
    end

    def self.defaults
      Hash[*(defsform(:cons, :eq, :listp, :set, :quote, :eval, :list, :if, :backquote) +
             defun(:car , :cdr))]
    end

  end
end
