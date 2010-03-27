require 'hatsunelisp'
require 'error'

module HatsuneLisp
  class SymbolTable < Hash
    def initialize(parent = Hash.new)
      super(){ |key, this| parent[key] }
    end

    def []=(key, val)
      if not(key.is_a?(Symbol)) then
        raise TypeError.new("#{key.class}(#{key.inspect})に値を代入しようとしました")
      end
      super(key, val)
    end

  end
end
