# -*- coding: utf-8 -*-
require_relative 'error'

module MIKU
  class RootSymbolTable
    def self.generate
      @root_symbol_table ||= RootSymbolTable.new
    end

    def initialize
      @__cache__table = {}
    end

    def root?
      true
    end

    def [](key)
      @__cache__table[key] ||= table(key)
    end

    private

    def table(key)
      case key.to_sym
      when :cons, :listp, :set, :function, :value, :quote, :eval, :list,
           :if, :backquote, :macro, :require_runtime_library, :+, :-, :*, :/,
           :<, :>, :<=, :>=, :eq, :eql, :equal
        Cons.new(nil, Primitive.new(key))
      when :lambda
        Cons.new(nil, Primitive.new(:negi))
      when :def
        Cons.new(nil, Primitive.new(:defun))
      when :'macro-expand'
        Cons.new(nil, Primitive.new(:macro_expand))
      when :'macro-expand-all'
        Cons.new(nil, Primitive.new(:macro_expand_all))
      when :'to-ruby'
        Cons.new(nil, Primitive.new(:to_ruby))
      when :"="
        Cons.new(nil, Primitive.new(:eq))
      when :not
        Cons.new(nil, Primitive.new(:_not))
      when :true
        Cons.new(true, nil)
      when :false
        Cons.new(false, nil)
      when *Object.constants
        Cons.new(Object.const_get(key.to_s))
      end
    end
  end

  class SymbolTable < Hash

    INITIALIZE_FILE = File.expand_path(File.join(__dir__, 'init.miku'))

    # :caller-file "呼び出し元ファイル名"
    # :caller-line 行
    # :caller-function :関数名
    def initialize(parent = nil, default = {})
      if parent
        @parent = parent
      else
        @parent = MIKU::SymbolTable.initialized_table end
      super(){ |this, key| @parent[key.to_sym] }
      merge!(default) unless default.empty?
    end

    def root?
      false
    end

    # なんかわからんけどRootSymbolTableの一個手前を返すらしい
    def ancestor
      if @parent.root?
        self
      else
        @parent.ancestor
      end
    end

    def []=(key, val)
      if not(key.is_a?(Symbol)) then
        raise ExceptionDelegator.new("#{key.inspect} に値 #{val.inspect} を代入しようとしました", TypeError) end
      super(key, val) end

    def bind(key, val, setfunc)
      cons = self[key]
      if cons
        cons.method(setfunc).call(val)
      else
        self[key] = nil.method(setfunc).call(val) end end

    def set(key, val)
      if not(key.is_a?(Symbol)) then
        raise ExceptionDelegator.new("#{key.inspect} に値 #{val.inspect} を代入しようとしました", TypeError) end
      bind(key.to_sym, val, :setcar) end

    def defun(key, val)
      if not(key.is_a?(Symbol)) then
        raise ExceptionDelegator.new("#{key.inspect} に関数 #{val.inspect} を代入しようとしました", TypeError) end
      bind(key.to_sym, val, :setcdr) end

    def miracle_binding(keys, values)
      _miracle_binding(SymbolTable.new(self), keys, values) end

    def _miracle_binding(symtable, keys, values)
      if(keys.is_a? Enumerable and values.is_a? Enumerable)
        key = keys.car
        val = values.car
        if key.is_a? List
          if key[0] == :rest
            symtable[key[1]] = Cons.new(values)
            return symtable end
        else
          symtable[key] = Cons.new(val) end
        _miracle_binding(symtable, keys.cdr, values.cdr) end
      symtable end

    def self.initialized_table
      @@initialized_table ||= (@@initialized_table = MIKU::SymbolTable.new(RootSymbolTable.generate)).run_init_script end

    def run_init_script
      miku_stream(File.open(INITIALIZE_FILE), self)
      self end

  end
end
