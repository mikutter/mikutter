# hatsune lisp is moest language

require 'miku'
require 'error'
require 'stringio'

module MIKU

  def self.parse(str)
    if(str.is_a?(String))
      _parse(StringIO.new(str, 'r').extend(StaticCode))
    else
      str.extend(StaticCode) if not str.is_a? StaticCode
      str.staticcode_file = str.path if defined? str.path
      _parse(str)
    end
  end

  def self._parse(s)
    c = skipspace(s)
    case c
    when ';' then
      _comment(s)
      _parse(s)
    when '(' then
      _list(s)
    when '"' then
      _string(s)
    when '`' then
      Cons.list(:backquote, _parse(s)).extend(StaticCode).staticcode_copy_info(s.staticcode_dump)
    when ',' then
      c = s.getc.chr
      if c == '@' then
        Cons.list(:comma_at, _parse(s)).extend(StaticCode).staticcode_copy_info(s.staticcode_dump)
      else
        s.ungetc(c[0])
        Cons.list(:comma, _parse(s)).extend(StaticCode).staticcode_copy_info(s.staticcode_dump)
      end
    when '\'' then
      Cons.list(:quote, _parse(s)).extend(StaticCode).staticcode_copy_info(s.staticcode_dump)
    else
      _symbol(c, s)
    end
  end

  def self._comment(s)
    read_to(s){ |c| c == "\n" }
  end

  def self._list(s)
    scd = s.staticcode_dump
    c = s.getc.chr
    return nil if c == ')'
    s.ungetc(c[0])
    car = _parse(s)
    c = skipspace(s)
    if(c == '.') then
      cdr = _parse(s)
      s.ungetc(skipspace(s)[0])
      raise SyntaxError.new('ドット対がちゃんと終わってないよ',s) if(s.getch != ')')
      return Cons.new(car, cdr).extend(StaticCode).staticcode_copy_info(scd)
    else
      s.ungetc(c[0])
      return Cons.new(car, _list(s)).extend(StaticCode).staticcode_copy_info(scd)
    end
  end

  def self._string(s)
    result = read_to(s){ |c| c == '"' }
    s.getc
    result.extend(StaticCode).staticcode_copy_info(s)
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
    elsif(sym == '')
      raise MIKU::EndofFile
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
    s.staticcode_line += 1 if c == "\n"
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
