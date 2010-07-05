require 'error'

module MIKU
  class SymbolTable < Hash
    def initialize(parent = SymbolTable.defaults)
      @parent = parent
      super(){ |this, key| parent[key.to_sym] } end

    def []=(key, val)
      if not(key.is_a?(Symbol)) then
        raise ExceptionDelegator.new("#{key.class}(#{key.inspect})に値を代入しようとしました", TypeError) end
      super(key, val) end

    def bind(key, val, setfunc)
      cons = self[key]
      if cons
        cons.method(setfunc).call(val)
      else
        self[key] = nil.method(setfunc).call(val) end end

    def set(key, val)
      if not(key.is_a?(Symbol)) then
        raise ExceptionDelegator.new("#{key.class}(#{key.inspect})に値を代入しようとしました", TypeError) end
      bind(key.to_sym, val, :setcar) end

    def defun(key, val)
      if not(key.is_a?(Symbol)) then
        raise ExceptionDelegator.new("#{key.class}(#{key.inspect})に値を代入しようとしました", TypeError) end
      bind(key.to_sym, val, :setcdr) end

    def miracle_binding(keys, values)
      result = SymbolTable.new(self)
      count = 0
      values.each{ |val|
        result[keys[count]] = Cons.new(val)
        count += 1 }
      p result
      result
    end

    def self.defsform(fn=nil, *other)
      return [] if fn == nil
      [fn , Cons.new(nil, Primitive.new(fn))] + defsform(*other) end

    def self.defun(fn=nil, *other)
      return [] if fn == nil
      [fn , Cons.new(nil, fn)] + defun(*other) end

    def self.consts
      Module.constants.map{ |c| [c.to_sym, Cons.new(eval(c))] }.inject([]){ |a, b| a + b } end

    def self.defaults
      Hash[*(defsform(:cons, :eq, :listp, :set, :function, :value, :quote, :eval, :list,
                      :if, :backquote) +
             [:lambda , Cons.new(nil, Primitive.new(:negi))] +
             [:def , Cons.new(nil, Primitive.new(:defun))] + consts)] end
  end
end
