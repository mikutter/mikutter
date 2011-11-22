# -*- coding:utf-8 -*-
require_relative 'node'
require_relative 'primitive'

module MIKU

  # MIKUがリストとして扱えるようにするためのmix-in。
  # これをincludeするクラスは、car, cdr, setcar, setcdrを実装している必要がある。
  module List
    include Node
    include Enumerable

    # _beg_ 番目の要素を取得する。
    # 範囲を超えていた場合nilを返す。
    # Rangeが渡されたら、その範囲を切り取って返す。
    # _en_ が指定されたら、 _beg_ .. _en_ を返す。
    def [](beg, en=nil)
      if not(en) and beg.is_a?(Integer)
        nth(beg)
      elsif en
        to_a[beg, en]
      else
        to_a[beg] end end

    # _index_ 番目の要素を _value_ に置き換える。
    # _index_ がRangeなら、その範囲を配列 _value_ で置き換える。
    def []=(index, value)
      if index.is_a?(Integer)
        nthcdr(index).setcar(value)
      elsif index.is_a?(Range)
        nthcdr(index.first).setcdr(value.to_cons.copycdr.set_terminator(nthcdr(index.last)))
      end
    end

    # set_terminatorと同じだが、非破壊的。
    def +(other)
      copycdr.set_terminator(other)
    end

    def size
      if cdr.is_a? List
        1 + cdr.size
      else
        1 end end

    def copycdr
      if cdr.is_a? List
        Cons.new(car, cdr.copycdr)
      else
        Cons.new(car, (cdr.dup rescue cdr)) end end

    def nth(n)
      result = nthcdr(n)
      if not result.respond_to?(:car)
        raise ExceptionDelegator.new("nthがリストではないもの(#{MIKU.unparse self}の#{n}番目)に対して使われました", TypeError)
      end
      result.car
    end

    def nthcdr(n)
      raise "cant comparable #{n.inspect} in #{self.inspect}" if not n.respond_to?(:<=)
      return self if(n <= 0)
      self.cdr.nthcdr(n-1)
    end

    def terminator
      if cdr.is_a? List
        cdr.terminator
      else
        cdr end end

    def terminator=(value)
      set_terminator(value)
      value end

    def set_terminator(value)
      if cdr.is_a? List
        cdr.set_terminator(value)
      else
        setcdr(value) end
      self end

    alias append set_terminator

    def to_cons
      if cdr.is_a? List
        MIKU::Cons.new(car, cdr.to_cons)
      else
        MIKU::Cons.new(car, cdr) end end

    def list_check(symtable, list)
      raise ArgumentError.new("#{node.inspect} の評価結果 #{list.inspect}の#{parse_caller(caller(2))[2]}を参照しました") if not list.is_a? List
      return list
    end

    def mapcarcdr(converter)
      Cons.new(*[car, cdr].map{ |node|
                 if(node.is_a?(List))
                   node.mapcarcdr(converter)
                 else
                   converter.call(node) end }) end

    # ツリーの葉をすべてruleにしたがって置換する。
    # ruleには、((検索するノード 置換するノード) ...)というリストを渡す
    def replace(rule)
      mapcarcdr(lambda{ |n|
                  r = rule.assoc(n)
                  if r.nil? then n else r[1] end }) end

    def miku_eval(symtable=SymbolTable.new)
      return nil if(empty?)
      result = nil
      begin
        operator = get_function(symtable)
        if operator.is_a? Primitive
          result = operator.call(symtable, *cdr.to_a)
        elsif operator.respond_to?(:macro_expand)
          result = miku(operator.macro_expand(*cdr.to_a), symtable)
        elsif operator.respond_to?(:call)
          result = operator.call(*evaluate_args(symtable))
        elsif operator.is_a? Symbol
          result = call_rubyfunc(operator, *evaluate_args(symtable))
        else
          raise NoMithodError.new(operator, self)
        end
      rescue ExceptionDelegator => e
        e.fire(self)
      end
      if result.is_a? List
        result.dup.extend(StaticCode).staticcode_copy_info(self)
      else
        result end end

    def call_rubyfunc(fn, receiver, *args)
      func = if receiver.respond_to?(fn) then receiver.method(fn)
             elsif Kernel.respond_to?(fn) then
               args.unshift(receiver)
               Kernel.method(fn) end
      if func
        begin
          block = nil
          count = if func.arity < 0 then -(func.arity)+1 else func.arity end
          if args.size > count
            atmp = args.dup
            block = atmp.pop
            if(block.respond_to? :call)
              args = atmp
            else
              block = nil end end
          func.call(*args, &block)
        rescue => e
          raise e end
      else
        raise NoMithodError.new(fn, self) end end

    def get_function(symtable)
      if car.is_a? Symbol
        symtable[car].cdr or symtable[car].car or car
      else
        miku_eval_another(symtable, car)
      end
    end

    def evaluate_args(scope)
      cdr.map{|node| miku(node, scope)} if cdr.is_a?(Enumerable)
    end

    def unparse
      '(' + _unparse
    end

    def _unparse
      result = ''
      result << MIKU.unparse(self.car)
      if(self.cdr == nil)
        result + ')'
      elsif(self.cdr.is_a? List)
        result + ' ' + self.cdr._unparse
      else
        result + ' . ' + MIKU.unparse(self.cdr) + ')'
      end
    end
  end

end

require_relative 'cons'
require_relative 'array'
