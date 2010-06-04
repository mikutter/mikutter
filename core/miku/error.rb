module MIKU
  class SyntaxError < Exception
    def initialize(msg, scan)
      super(msg + " in #{scan.pos}")
    end
  end

  class ArgumentError < Exception
    def initialize(msg)
      super(msg)
    end
  end

  class TypeError < Exception
    def initialize(msg)
      super(msg)
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

end
