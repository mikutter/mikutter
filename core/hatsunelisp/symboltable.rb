require 'hatsunelisp'
require 'error'

module HatsuneLisp
  class SymbolTable < Hash
    def initialize(parent = Hash.new(Cons.new(nil, nil)))
      super(){ |key, this| parent[key] }
    end

    def []=(key, val)
      if not(key.is_a?(Symbol)) then
        raise TypeError.new("#{key.class}(#{key.inspect})に値を代入しようとしました")
      end
      super(key, self[key].setcar(val))
    end

  end
end
