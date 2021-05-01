# -*- coding: utf-8 -*-

module MIKU
  module ToRuby
    STRING_LITERAL_ESCAPE_MAP = {'\\' => '\\\\', "'" => "\\'"}.freeze
    STRING_LITERAL_ESCAPE_MATCHER = Regexp.union(STRING_LITERAL_ESCAPE_MAP.keys).freeze

    class << self
      def indent(code)
        code.each_line.map{|l| "  #{l}"}.join("\n")
      end

      def progn(list, options={quoted: false, use_result: true})
        if options[:use_result]
          progn_code = list.dup
          progn_last = progn_code.pop
          [*progn_code.map{|n| to_ruby(n, use_result: false)}, to_ruby(progn_last, use_result: :to_return)].join("\n")
        else
          list.map{|n| to_ruby(n, use_result: false)}.join("\n") end end

      # rubyに変換して返す
      # 
      # ==== Args
      # [sexp] MIKUの式(MIKU::Nodeのインスタンス)
      # [options] 以下の値を持つHash
      #   quoted :: 真ならクォートコンテキスト内。シンボルが変数にならず、シンボル定数になる
      #   use_result :: 結果を使うなら真。そのコンテキストの戻り値として使うだけなら、 :to_return を指定
      def to_ruby(sexp, options={quoted: false, use_result: true})
        expanded = sexp
        case expanded
        when Symbol
          (options[:quoted] ? ":" : "") + "#{expanded.to_s}"
        when Numeric
          expanded.to_s
        when String
          string_literal(expanded)
        when TrueClass
          'true'
        when FalseClass
          'false'
        when NilClass
          'nil'
        when List
          if options[:quoted]
            '[' + expanded.map{|node| to_ruby(node, quoted: true, use_result: true)}.join(", ") + ']'
          else
            operator = expanded.car
            case operator
            when :quote
              to_ruby(expanded[1], quoted: true, use_result: true)
            when :<, :>, :<=, :>=, :eql, :equal, :and, :or, :==
                converted = {
                :< => "<", :> => ">", :<= => "<=", :>= => ">=", :eql => "==", :equal => "===", :and => "and", :or => "or", :== => "=="}[operator]
              if 2 == expanded.size
                to_ruby(expanded[1], use_result: options[:use_result])
              else
                expanded.cdr.enum_for(:each_cons, 2).map{ |a, b|
                  "#{to_ruby(a)} #{converted} #{to_ruby(b)}" }.join(' and ')
              end
            when :eq
              expanded.cdr.enum_for(:each_cons, 2).map{ |a, b|
                "#{to_ruby(a)}.equal?(#{to_ruby(b)})" }.join(' and ')
            when :+, :-, :*, :/
              expanded.cdr.join(" #{expanded.car.to_s} ")
            when :not
                '!(' + to_ruby(expanded[1]) + ')'
            when :progn
              "begin\n" + indent(progn(expanded.cdr.cdr, use_result: options[:use_result])) + "\nend\n"
            when :if
                if options[:use_result]
                  if 3 == expanded.size
                    if expanded[2].is_a?(List) and :progn == expanded[2].car
                      'if ' + to_ruby(expanded[1]) + "\n" + indent(progn(expanded[2].cdr)) + "\nend"
                    else
                      "(" + to_ruby(expanded[1]) + " and " + to_ruby(expanded[2]) + ")" end
                  else
                    else_code = expanded.cdr.cdr
                    else_last = else_code.pop
                    'if ' + to_ruby(expanded[1]) + "\n" + indent(to_ruby(expanded[2])) +
                      "\nelse\n" + indent([*else_code.map{|n| to_ruby(n, use_result: false)}, to_ruby(else_last)].join("\n")) +
                      "\nend" end
                else
                  if 3 == expanded.size
                    to_ruby(expanded[2], use_result: false) + ' if ' + to_ruby(expanded[1])
                  else
                    'if ' + to_ruby(expanded[1]) + "\n" + indent(to_ruby(expanded[2])) +
                      "\nelse\n" + indent(expanded.cdr.cdr.map{|n| to_ruby(n, use_result: false)}.join("\n")) +
                      "\nend" end end
            else
              if expanded[1].is_a? Symbol
                args = [":" + operator.to_s, *(expanded.size > 2 ? expanded.cdr.cdr.map{|node|to_ruby(node)} : [])].join(", ")
                "#{to_ruby(expanded[1])}.__send__(#{args})"
              else
                args = expanded.size > 2 ? expanded.cdr.cdr.map{|node|to_ruby(node)}.join(",") : ""
                "#{to_ruby(expanded[1])}.#{operator.to_s}(#{args})" end end end
        else
          expanded.to_s
        end
      end

      def string_literal(str)
        escaped = str.gsub(STRING_LITERAL_ESCAPE_MATCHER, STRING_LITERAL_ESCAPE_MAP)
        "'#{escaped}'"
      end
    end
  end
end
