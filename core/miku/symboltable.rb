# -*- coding: utf-8 -*-
require_relative 'error'

module MIKU
  class SymbolTable < Hash

    INITIALIZE_FILE = File.expand_path(File.join(File.dirname(__FILE__), 'init.miku'))

    # :caller-file "呼び出し元ファイル名"
    # :caller-line 行
    # :caller-function :関数名
    def initialize(parent = nil, default = {})
      if parent
        @parent = parent
      else
        @parent = MIKU::SymbolTable.initialized_table end
      if(SymbolTable.defaults.equal?(parent))
        def self.ancestor
          self end end
      super(){ |this, key| @parent[key.to_sym] }
      merge!(default) unless default.empty?
    end

    def ancestor
      @parent.ancestor end

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
      @@initialized_table ||= (@@initialized_table = MIKU::SymbolTable.new(SymbolTable.defaults)).run_init_script end

    def self.defsform(fn=nil, *other)
      return [] if fn == nil
      [fn , Cons.new(nil, Primitive.new(fn))] + defsform(*other) end

    def self.defun(fn=nil, *other)
      return [] if fn == nil
      [fn , Cons.new(nil, fn)] + defun(*other) end

    def self.consts
      Module.constants.map{ |c| [c.to_sym, Cons.new(eval(c.to_s))] }.inject([]){ |a, b| a + b } end
    # Module.constants.map{ |c| [c.to_sym, Cons.new(eval(c))] }.inject([]){ |a, b| a + b } end

    def self.defaults
      @@defaults ||= __defaults end

    def self.__defaults
      default = Hash[*(defsform(:cons, :eq, :listp, :set, :function, :value, :quote, :eval, :list,
                                :if, :backquote, :macro, :require_runtime_library, :+, :-, :*, :/,
                                :<, :>, :<=, :>=, :eq, :eql, :equal) +
                       [:lambda , Cons.new(nil, Primitive.new(:negi)),
                        :def , Cons.new(nil, Primitive.new(:defun)),
                        :'macro-expand' , Cons.new(nil, Primitive.new(:macro_expand)),
                        :'macro-expand-all' , Cons.new(nil, Primitive.new(:macro_expand_all)),
                        :"=", Cons.new(nil, Primitive.new(:eq)),
                        :not, Cons.new(nil, Primitive.new(:_not)),
                        :true, Cons.new(true, nil),
                        :false, Cons.new(false, nil)
                       ] + consts)].freeze
      Hash.new{ |h, k|
        if default[k]
          h[k] = default[k]
        elsif /^[A-Z][a-zA-Z0-9_]*/ =~ k.to_s and klass = eval(k.to_s)
          h[k] = klass
        end }
    end

    def run_init_script
      miku_stream(File.open(INITIALIZE_FILE), self)
      self end

  end
end
