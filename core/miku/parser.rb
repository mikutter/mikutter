# hatsune lisp is moest language

require 'miku'
require 'error'
require 'stringio'

module MIKU

  def self.parse(str)
    if(str.is_a?(String)) then
      _parse(StringIO.new(str, 'r'))
    else
      _parse(str)
    end
  end

  def self._parse(s)
    c = skipspace(s)
    if c == '(' then
      _list(s)
    elsif c == '"' then
      _string(s)
    elsif c == '`' then
      [:backquote, _parse(s)]
    elsif c == ',' then
      c = s.getc.chr
      if c == '@' then
        list = _parse(s)
        raise SyntaxError.new(',@がリスト以外に対して適用されました',s) if not list.is_a?(List)
        [:comma_at, list]
      else
        s.ungetc(c[0])
        [:comma, _parse(s)]
      end
    elsif c == '\'' then
      [:quote, _parse(s)]
    else
      _symbol(c, s)
    end
  end

  def self._list(s)
    c = s.getc.chr
    return nil if c == ')'
    s.ungetc(c[0])
    car = _parse(s)
    c = skipspace(s)
    if(c == '.') then
      cdr = _parse(s)
      s.ungetc(skipspace(s)[0])
      raise SyntaxError.new('ドット対がちゃんと終わってないよ',s) if(s.getch != ')')
      return Cons.new(car, cdr)
    else
      s.ungetc(c[0])
      return Cons.new(car, _list(s))
    end
  end

  def self._string(s)
    result = read_to(s){ |c| c == '"' }
    s.getc
    result
  end

  def self._symbol(c, s)
    sym = c + read_to(s){ |c| not(c =~ /[^\(\)\.',#\s]/) }
    raise SyntaxError.new('### 深刻なエラーが発生しました ###',s) if not(sym)
    if(sym =~ /^-?[0-9]+$/) then
      sym.to_i
    elsif(sym =~ /^-?[0-9]+\.[0-9]+$/) then
      sym.to_f
    elsif(sym == 'nil') then
      nil
    else
      sym.to_sym
    end
  end

  def self.read_to(s, &cond)
    c = s.getc
    return '' if not c
    c = c.chr
    if cond.call(c) then
      s.ungetc(c[0])
      return ''
    end
    c + read_to(s, &cond)
  end

  def self.skipspace(s)
    c = s.getc
    return '' if not c
    c = c.chr
    return skipspace(s) if(c =~ /\s/)
    c
  end

  def self.unparse(val)
    if val === nil
      'nil'
    elsif(val.is_a?(List))
      val.unparse
    else
      val.to_s
    end
  end

end
