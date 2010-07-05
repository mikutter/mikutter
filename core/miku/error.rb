module MIKU

  class MikuException < Exception
  end

  class ExceptionDelegator < Exception
    def initialize(msg, exceptionclass)
      @exceptionclass = exceptionclass
      super(msg)
    end

    def fire(scan)
      raise @exceptionclass.new(to_s, scan)
    end
  end

  class SyntaxError < MikuException
    def initialize(msg, scan)
      super(msg + " #{scan.staticcode_file} in line #{scan.staticcode_line}\n  #{MIKU.unparse(scan)}")
    end
  end

  class ArgumentError < MikuException
    def initialize(msg, scan)
      super(msg + " #{scan.staticcode_file} in line #{scan.staticcode_line}\n  #{MIKU.unparse(scan)}")
    end
  end

  class TypeError < MikuException
    def initialize(msg, scan)
      super(msg + " #{scan.staticcode_file} in line #{scan.staticcode_line}\n  #{MIKU.unparse(scan)}")
    end
  end

  def parse_caller(at)
    if /^(.+?):(\d+)(?::in `(.*)')?/ =~ at
      file = $1
      line = $2.to_i
      method = $3
      [file, line, method]
    end
  end

  class NoMithodError < MikuException
    def initialize(name, scan)
      super("undefined function '#{name.inspect}' #{scan.staticcode_file} in line #{scan.staticcode_line}\n  #{MIKU.unparse(scan)}")
    end
  end

  class EndofFile < MikuException
  end

end
